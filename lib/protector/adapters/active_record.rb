module Protector
  module Adapters
    module ActiveRecord
      def self.activate!
        ::ActiveRecord::Base.send :include, Protector::Adapters::ActiveRecord::Base
      end

      module Base
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
          include Protector::DSL::Entry

          before_validation(on: :create) do
            @protector_subject ? creatable? : true
          end

          before_validation(on: :update) do
            @protector_subject ? updatable? : true
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
          protector_meta.creatable?(changed)
        end

        def updatable?
          protector_meta.updatable?(changed)
        end

        def destroyable?
          protector_meta.destroyable?
        end
      end
    end
  end
end