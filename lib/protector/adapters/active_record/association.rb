module Protector
  module Adapters
    module ActiveRecord
      # Patches `ActiveRecord::Associations::SingularAssociation` and `ActiveRecord::Associations::CollectionAssociation`
      module Association
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base

          # AR 4 has renamed `scoped` to `scope`
          if method_defined?(:scope)
            alias_method_chain :scope, :protector
          else
            alias_method 'scope_without_protector', 'scoped'
            alias_method 'scoped', 'scope_with_protector'
          end

          alias_method_chain :build_record, :protector
        end

        # Wraps every association with current subject
        def scope_with_protector(*args)
          scope = scope_without_protector(*args)
          scope = scope.restrict!(protector_subject) if protector_subject?
          scope
        end

        # Forwards protection subject to the new instance
        def build_record_with_protector(*args)
          return build_record_without_protector(*args) unless protector_subject?

          protector_permit_strong_params(args)
          build_record_without_protector(*args).restrict!(protector_subject)
        end

        private

        def protector_meta(subject=protector_subject)
          klass.protector_meta.evaluate(subject)
        end

        def protector_permit_strong_params(args)
          Protector::ActiveRecord::Adapters::StrongParameters.sanitize! args, true, protector_meta
        end
      end
    end
  end
end
