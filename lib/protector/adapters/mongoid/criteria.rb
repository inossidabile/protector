module Protector
  module Adapters
    module Mongoid
      module Criteria
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
        end

        # Gets {Protector::DSL::Meta::Box} of this relation
        def protector_meta(subject=protector_subject)
          @klass.protector_meta.evaluate(subject)
        end

        # @note Unscoped relation drops properties and therefore should be re-restricted
        def unscoped
          return super unless protector_subject?
          super.restrict!(protector_subject)
        end

        # Merges current relation with restriction and calls real `exists?`
        def exists?(*args)
          return super unless protector_subject?
          merge(protector_meta.relation).unrestrict!.exists? *args
        end

        
      end
    end
  end
end
