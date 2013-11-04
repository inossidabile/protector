module Protector
  module DSL
    # DSL meta storage and evaluator
    class Meta

      # Single DSL evaluation result
      class Box
        attr_accessor :adapter, :access, :destroyable

        # @param model [Class]              The class of protected entity
        # @param fields [Array<String>]     All the fields the model has
        # @param subject [Object]           Restriction subject
        # @param entry [Object]             An instance of the model
        # @param blocks [Array<Proc>]       An array of `protect` blocks
        def initialize(adapter, model, fields, subject, entry, blocks)
          @adapter     = adapter
          @model       = model
          @fields      = fields
          @access      = {}
          @scope_procs = []
          @destroyable = false

          Protector.insecurely do
            blocks.each do |b|
              case b.arity
              when 2
                instance_exec(subject, entry, &b)
              when 1
                instance_exec(subject, &b)
              else
                instance_exec(&b)
              end
            end
          end
        end

        # Checks whether protection with given subject
        # has the selection scope defined
        def scoped?
          Protector.config.paranoid? || @scope_procs.length > 0
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
          @scope_procs << block
          @relation = false
        end

        def scope_procs
          return [@adapter.null_proc] if @scope_procs.empty? && Protector.config.paranoid?
          @scope_procs
        end

        def relation
          return false unless scoped?

          @relation ||= eval_scope_procs @model
        end

        def eval_scope_procs(instance)
          scope_procs.reduce(instance) do |relation, scope_proc|
            relation.instance_eval(&scope_proc)
          end
        end

        # Enables action for given fields.
        #
        # Built-in possible actions are: `:read`, `:update`, `:create`.
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
        #     can :read               # Can read any field
        #     can :read, 'f1'         # Can read `f1` field
        #     can :read, %w(f2 f3)    # Can read `f2`, `f3` fields
        #     can :update, f1: 1..2   # Can update f1 field with values between 1 and 2
        #
        #     # Can create f1 field with value equal to 'olo'
        #     can :create, f1: lambda{|x| x == 'olo'}
        #   end
        def can(action, *fields)
          action = deprecate_actions(action)

          return @destroyable = true if action == :destroy

          @access[action] = {} unless @access[action]

          if fields.length == 0
            @fields.each { |f| @access[action][f.to_s] = nil }
          else
            fields.each do |a|
              if a.is_a?(Array)
                a.each { |f| @access[action][f.to_s] = nil }
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
          action = deprecate_actions(action)

          return @destroyable = false if action == :destroy

          return unless @access[action]

          if fields.length == 0
            @access.delete(action)
          else
            fields.each do |a|
              if a.is_a?(Array)
                a.each { |f| @access[action].delete(f.to_s) }
              else
                @access[action].delete(a.to_s)
              end
            end

            @access.delete(action) if @access[action].empty?
          end
        end

        # @endgroup

        # Checks whether given field of a model is readable in context of current subject
        def readable?(field)
          @access[:read] && @access[:read].key?(field)
        end

        # Checks whether you can create a model with given field in context of current subject
        def creatable?(fields=false)
          modifiable? :create, fields
        end

        def first_uncreatable_field(fields)
          first_unmodifiable_field :create, fields
        end

        # Checks whether you can update a model with given field in context of current subject
        def updatable?(fields=false)
          modifiable? :update, fields
        end

        def first_unupdatable_field(fields)
          first_unmodifiable_field :update, fields
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
          return destroyable? if action == :destroy

          return false unless @access[action]
          return !@access[action].empty? unless field

          @access[action].key?(field.to_s)
        end

        def cannot?(*args)
          !can?(*args)
        end

        private

        def first_unmodifiable_field(part, fields)
          return (fields.keys.first || '-') unless @access[part]

          diff = fields.keys - @access[part].keys
          return diff.first if diff.length > 0

          fields.each do |k, v|
            case x = @access[part][k]
            when Range
              return k unless x.include?(v)
            when Proc
              return k unless Protector.insecurely{ x.call(v) }
            else
              return k if !x.nil? && x != v
            end
          end

          false
        end

        def modifiable?(part, fields=false)
          return false unless @access[part]
          return false if fields && first_unmodifiable_field(part, fields)
          true
        end

        def deprecate_actions(action)
          if action == :view
            ActiveSupport::Deprecation.warn ":view rule has been deprecated and replaced with :read! "+
              "Starting from version 1.0 :view will be treated as a custom rule."

            :read
          else
            action
          end
        end
      end

      def initialize(adapter, model, &fields_proc)
        @adapter     = adapter
        @model       = model
        @fields_proc = fields_proc
      end

      def fields
        @fields ||= @fields_proc.call
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
      # @param subject [Object]           Restriction subject
      # @param entry [Object]             An instance of the model
      def evaluate(subject, entry=nil)
        Box.new(@adapter, @model, fields, subject, entry, blocks)
      end
    end

    module Base
      extend ActiveSupport::Concern

      # Property accessor that makes sure you don't use
      # subject on a non-protected model
      def protector_subject
        unless protector_subject?
          fail "Unprotected entity detected for '#{self.class}': use `restrict` method to protect it."
        end

        @protector_subject
      end

      # Assigns restriction subject
      #
      # @param [Object] subject         Subject to restrict against
      def restrict!(subject=nil)
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
      end
    end
  end
end
