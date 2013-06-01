require 'set'

module Protector
  module DSL
    # DSL meta storage and evaluator
    class Meta

      # Evaluation result moved out of Meta to make it thread-safe
      # and incapsulate better
      class Box
        attr_accessor :access, :relation, :destroyable

        def initialize(model, fields, subject, entry, blocks)
          @model       = model
          @fields      = fields
          @access      = {update: {}, view: {}, create: {}}
          @relation    = false
          @destroyable = false

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

        def scoped?
          !!@relation
        end

        def scope(&block)
          @relation = @model.instance_eval(&block)
        end

        def can(action, *fields)
          return @destroyable = true if action == :destroy
          return unless @access[action]

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

        def readable?(field)
          @access[:view].has_key?(field)
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

      def blocks
        @blocks ||= []
      end

      def <<(block)
        blocks << block
      end

      def evaluate(model, subject, fields=[], entry=nil)
        Box.new(model, fields, subject, entry, blocks)
      end
    end

    module Base
      extend ActiveSupport::Concern

      included do
        attr_reader :protector_subject
      end

      def restrict!(subject)
        @protector_subject = subject
        self
      end

      def unrestrict!
        @protector_subject = nil
        self
      end
    end

    module Entry
      extend ActiveSupport::Concern

      module ClassMethods
        def protect(&block)
          protector_meta << block
        end

        def protector_meta
          @protector_meta ||= Meta.new
        end
      end
    end
  end
end