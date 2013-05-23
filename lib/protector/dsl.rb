module Protector
  module DSL
    # DSL meta storage and evaluator
    class Meta
      class Box
        attr_accessor :access, :relation, :destroyable

        def initialize(model, fields, subject, entry, blocks)
          @model       = model
          @fields      = fields
          @access      = {update: {}, view: {}, create: {}}.with_indifferent_access
          @access_keys = {}.with_indifferent_access
          @relation    = false
          @destroyable = false

          blocks.each do |b|
            if b.arity == 2
              instance_exec subject, entry, &b
            elsif b.arity == 1
              instance_exec subject, &b
            else
              instance_exec &b
            end
          end

          @access.each{|k,v| @access_keys[k] = v.keys}
        end

        def scope(&block)
          @relation = @model.instance_eval(&block)
        end

        def can(action, *fields)
          return @destroyable = true if action == :destroy
          return unless @access[action]

          if fields.size == 0
            @fields.each{|f| @access[action][f] = nil}
          else
            fields.each do |a|
              if a.is_a?(Array)
                a.each{|f| @access[action][f] = nil}
              elsif a.is_a?(Hash)
                @access[action].merge!(a)
              else
                @access[action][a] = nil
              end
            end
          end
        end

        def cannot(action, *fields)
          return @destroyable = false if action == :destroy
          return unless @access[action]

          if fields.size == 0
            @access[action].clear
          else
            fields.each do |a|
              if a.is_a?(Array)
                a.each{|f| @access[action].delete(f)}
              else
                @access[action].delete(a)
              end
            end
          end
        end

        def readable?(field)
          @access_keys[:view].include?(field.to_s)
        end

        def creatable?(fields=false)
          modifiable? :create, fields
        end

        def updatable?(fields=false)
          modifiable? :update, fields
        end

        def destroyable?
          @destroyable
        end

        private

        def modifiable?(part, fields)
          return false unless @access_keys[part].length > 0

          if fields
            return false if (fields.keys - @access_keys[part]).length > 0

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

      def <<(block)
        (@blocks ||= []) << block
      end

      def evaluate(model, fields, subject, entry=nil)
        Box.new(model, fields, subject, entry, @blocks)
      end
    end

    module Base
      extend ActiveSupport::Concern

      included do
        attr_reader :protector_subject
      end

      def restrict(subject)
        @protector_subject = subject
        self
      end

      def unrestrict
        @protector_subject = nil
        self
      end
    end

    module Entry
      extend ActiveSupport::Concern

      included do
        class <<self
          attr_reader :protector_meta
        end
      end

      module ClassMethods
        def protect(&block)
          (@protector_meta ||= Meta.new) << block
        end
      end
    end
  end
end