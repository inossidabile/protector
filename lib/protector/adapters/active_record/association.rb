module Protector
  module Adapters
    module ActiveRecord
      module Association
        extend ActiveSupport::Concern

        included do
          if method_defined?(:scope)
            alias_method_chain :scope, :protector
          else
            alias_method "scope_without_protector", "scoped"
            alias_method "scoped", "scope_with_protector"
          end
        end

        def scope_with_protector(*args)
          scope_without_protector(*args).restrict!(owner.protector_subject)
        end
      end
    end
  end
end