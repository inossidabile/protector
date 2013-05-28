module Protector
  module Adapters
    module ActiveRecord
      module Association
        extend ActiveSupport::Concern

        included do
          alias_method_chain :scope, :protector
        end

        def scope_with_protector(*args)
          scope_without_protector(*args).restrict!(owner.protector_subject)
        end
      end

      module PreloaderAssociation
        extend ActiveSupport::Concern

        included do
          alias_method_chain :scope, :protector
        end

        def scope_with_protector
          scope_without_protector
        end
      end
    end
  end
end