module Protector
  module Adapters
    module ActiveRecord
      def self.activate!
        ::ActiveRecord::Base.send :include, Protector::Adapters::ActiveRecord::Base
        ::ActiveRecord::Relation.send :include, Protector::Adapters::ActiveRecord::Relation
      end

      module Base
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
          include Protector::DSL::Entry

          validate(on: :create) do
            return unless @protector_subject
            errors[:base] << I18n.t('protector.invalid') unless creatable?
          end

          validate(on: :update) do
            return unless @protector_subject
            errors[:base] << I18n.t('protector.invalid') unless updatable?
          end

          before_destroy do
            return true unless @protector_subject
            destroyable?
          end
        end

        module ClassMethods
          def restrict(subject)
            all.restrict(subject)
          end
        end

        def protector_meta
          unless @protector_subject
            raise "Unprotected entity detected: use `restrict` method to protect it."
          end

          self.class.protector_meta.evaluate(
            self.class,
            self.class.column_names,
            @protector_subject,
            self
          )
        end

        def visible?
          protector_meta.relation.where(
            self.class.primary_key => send(self.class.primary_key)
          ).any?
        end

        def creatable?
          fields = HashWithIndifferentAccess[changed.map{|x| [x, __send__(x)]}]
          protector_meta.creatable?(fields)
        end

        def updatable?
          fields = HashWithIndifferentAccess[changed.map{|x| [x, __send__(x)]}]
          protector_meta.updatable?(fields)
        end

        def destroyable?
          protector_meta.destroyable?
        end
      end

      module Relation
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base

          alias_method_chain :exec_queries, :protector
        end

        def protector_meta
          @klass.protector_meta.evaluate(@klass, @klass.column_names, @protector_subject)
        end

        def count
          super || 0
        end

        def sum
          super || 0
        end

        def calculate(*args)
          return super unless @protector_subject
          merge(protector_meta.relation).unrestrict.calculate *args
        end

        def exec_queries_with_protector(*args)
          return exec_queries_without_protector unless @protector_subject
          @records = merge(protector_meta.relation).unrestrict.send :exec_queries
        end
      end
    end
  end
end