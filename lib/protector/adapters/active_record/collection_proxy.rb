module Protector
  module Adapters
    module ActiveRecord
      # Patches `ActiveRecord::Associations::CollectionProxy`
      module CollectionProxy
        extend ActiveSupport::Concern
        delegate :protector_subject, :protector_subject?, :to => :@association

        def restrict!(*args)
          @association.restrict!(*args)
          self
        end
      end
    end
  end
end