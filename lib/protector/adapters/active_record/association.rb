module Protector
  module Adapters
    module ActiveRecord
      # Patches `ActiveRecord::Associations::SingularAssociation` and `ActiveRecord::Associations::CollectionAssociation`
      module Association
        extend ActiveSupport::Concern

        included do
          # AR 4 has renamed `scoped` to `scope`
          if method_defined?(:scope)
            alias_method_chain :scope, :protector
          else
            alias_method 'scope_without_protector', 'scoped'
            alias_method 'scoped', 'scope_with_protector'
          end

          alias_method_chain :build, :protector
        end

        # Wraps every association with current subject
        def scope_with_protector(*args)
          scope = scope_without_protector(*args)
          scope = scope.restrict!(owner.protector_subject) if owner.protector_subject?
          scope
        end

        # Forwards protection subject to the new instance
        def build_with_protector(*args, &block)
          return build_without_protector(*args, &block) unless owner.protector_subject?
          build_without_protector(*args, &block).restrict!(owner.protector_subject)
        end
      end
    end
  end
end
