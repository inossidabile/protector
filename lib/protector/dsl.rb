module Protector
  module DSL
    # DSL meta storage and evaluator
    class Meta

      # Single DSL evaluation result
      class Box
        attr_accessor :access, :scope_proc, :destroyable

        # @param model [Class]              The class of protected entity
        # @param fields [Array<String>]     All the fields the model has
        # @param subject [Object]           Restriction subject
        # @param entry [Object]             An instance of the model
        # @param blocks [Array<Proc>]       An array of `protect` blocks
        def initialize(model, fields, subject, entry, blocks)
          @model       = model
          @fields      = fields
          @access      = {update: {}, view: {}, create: {}}
          @scope_proc  = false
          @destroyable = false

          Protector.insecurely do
            blocks.each do |b|
              case b.arity
              when 2
                instance_exec subject, entry, &b
              when 1
                instance_exec subject, &b
              else
                instance_exec &b
              end
            end
          end
        end

        # Checks whether protection with given subject
        # has the selection scope defined
        def scoped?
          !!@scope_proc
        end

        # @group Protection DSL

        # Activates the scope that selections will
        # be filtered with
        #
        # @yield Calls given model methods before the selection
        #
        # @example
        #   protect do
        #     # You can select nothing!
        #     scope { none }
        #   end
        def scope(&block)
          @scope_proc = block

          @relation          = false
          @unscoped_relation = false
        end

        def relation
          return false unless scoped?

          unless @relation
            @relation = @model.instance_eval(&@scope_proc)
          end

          @relation
        end

        # Enables action for given fields.
        #
        # Built-in possible actions are: `:view`, `:update`, `:create`.
        # You can pass any other actions you want to use with {#can?} afterwards.
        #
        # **The method enables action for every field if `fields` splat is empty.**
        # Use {#cannot} to exclude some of them afterwards.
        #
        # The list of fields can be given as a Hash. In this form you can pass `Range`
        # or `Proc` as a value. First will make Protector check against value inclusion.
        # The latter will make it evaluate given lambda (which is supposed to return true or false
        # determining if the value should validate or not).
        #
        # @param action [Symbol]                Action to allow
        # @param fields [String, Hash, Array]   Splat of fields to allow action with
        #
        # @see #can?
        #
        # @example
        #   protect do
        #     can :view               # Can view any field
        #     can :view, 'f1'         # Can view `f1` field
        #     can :view, %w(f2 f3)    # Can view `f2`, `f3` fields
        #     can :update, f1: 1..2   # Can update f1 field with values between 1 and 2
        #
        #     # Can create f1 field with value equal to 'olo'
        #     can :create, f1: lambda{|x| x == 'olo'}
        #   end
        def can(action, *fields)
          return @destroyable = true if action == :destroy
          @access[action] = {} unless @access[action]

          if fields.size == 0
            @fields.each{|f| @access[action][f.to_s] = nil}
          else
            fields.each do |a|
              if a.is_a?(Array)
                a.each{|f| @access[action][f.to_s] = nil}
              elsif a.is_a?(Hash)
                @access[action].merge!(a.stringify_keys)
              else
                @access[action][a.to_s] = nil
              end
            end
          end
        end

        # Disables action for given fields.
        #
        # Works similar (but oppositely) to {#can}.
        #
        # @param action [Symbol]                Action to disallow
        # @param fields [String, Hash, Array]   Splat of fields to disallow action with
        #
        # @see #can
        # @see #can?
        def cannot(action, *fields)
          return @destroyable = false if action == :destroy
          return unless @access[action]

          if fields.size == 0
            @access[action].clear
          else
            fields.each do |a|
              if a.is_a?(Array)
                a.each{|f| @access[action].delete(f.to_s)}
              else
                @access[action].delete(a.to_s)
              end
            end
          end
        end

        # @endgroup

        # Checks whether given field of a model is readable in context of current subject
        def readable?(field)
          @access[:view].has_key?(field)
        end

        # Checks whether you can create a model with given field in context of current subject
        def creatable?(fields=false)
          modifiable? :create, fields
        end

        # Checks whether you can update a model with given field in context of current subject
        def updatable?(fields=false)
          modifiable? :update, fields
        end

        # Checks whether you can destroy a model in context of current subject
        def destroyable?
          @destroyable
        end

        # Check whether you can perform custom action for given fields (or generally if no `field` given)
        #
        # @param [Symbol] action        Action to check against
        # @param [String] field         Field to check against
        def can?(action, field=false)
          return false unless @access[action]
          return !@access[action].empty? if field === false
          @access[action].has_key?(field.to_s)
        end

        private

        def modifiable?(part, fields)
          keys = @access[part].keys
          return false unless keys.length > 0

          if fields
            return false if (fields.keys - keys).length > 0

            fields.each do |k,v|
              case x = @access[part][k]
              when Range
                return false unless x.include?(v)
              when Proc
                return false unless x.call(v)
              end
            end
          end

          true
        end
      end

      # Storage for `protect` blocks
      def blocks
        @blocks ||= []
      end

      # Register another protection block
      def <<(block)
        blocks << block
      end

      # Calculate protection at the context of subject
      #
      # @param model [Class]              The class of protected entity
      # @param subject [Object]           Restriction subject
      # @param fields [Array<String>]     All the fields the model has
      # @param entry [Object]             An instance of the model
      def evaluate(model, subject, fields=[], entry=nil)
        Box.new(model, fields, subject, entry, blocks)
      end
    end

    module Base
      extend ActiveSupport::Concern

      # Property accessor that makes sure you don't use
      # subject on a non-protected model
      def protector_subject
        unless protector_subject?
          raise "Unprotected entity detected: use `restrict` method to protect it."
        end

        @protector_subject
      end

      # Assigns restriction subject
      #
      # @param [Object] subject         Subject to restrict against
      def restrict!(subject)
        @protector_subject = subject
        @protector_subject_set = true
        self
      end

      # Clears restriction subject
      def unrestrict!
        @protector_subject = nil
        @protector_subject_set = false
        self
      end

      # Checks if model was restricted
      def protector_subject?
        @protector_subject_set == true && !Thread.current[:protector_disabled]
      end
    end

    module Entry
      extend ActiveSupport::Concern

      module ClassMethods
        # Registers protection DSL block
        # @yield [subject, instance]        Evaluates conditions described in terms of {Protector::DSL::Meta::Box}.
        # @yieldparam subject [Object]      Subject that object was restricted with
        # @yieldparam instance [Object]     Reference to the object being restricted (can be nil)
        def protect(&block)
          protector_meta << block
        end

        # Storage of {Protector::DSL::Meta}
        def protector_meta
          @protector_meta ||= Meta.new
        end
      end
    end
  end
end