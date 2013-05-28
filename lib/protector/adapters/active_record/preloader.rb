module Protector
  module Adapters
    module ActiveRecord
      module Preloader extend ActiveSupport::Concern

        module Association extend ActiveSupport::Concern
          included do
            if method_defined?(:scope)
              alias_method_chain :scope, :protector
            else
              alias_method "scope_without_protector", "scoped"
              alias_method "scoped", "scope_with_protector"
            end
          end

          def protector_subject
            # Owners are always loaded from the single source
            # having same protector_subject
            owners.first.protector_subject
          end

          def scope_with_protector(*args)
            return scope_without_protector unless protector_subject

            @meta ||= klass.protector_meta.evaluate(klass, protector_subject)
            scope_without_protector.merge(@meta.relation)
          end
        end
      end
    end
  end
end