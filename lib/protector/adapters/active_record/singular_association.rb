module Protector
  module Adapters
    module ActiveRecord
      # Patches `ActiveRecord::Associations::SingularAssociation`
      module SingularAssociation
        extend ActiveSupport::Concern

        included do
          alias_method :reader_without_protector, :reader
          alias_method :reader, :reader_with_protector
        end

        # Reader has to be explicitly overrided for cases when the
        # loaded association is cached
        def reader_with_protector(*args)
          return reader_without_protector(*args) unless protector_subject?
          reader_without_protector(*args).try :restrict!, protector_subject
        end

        # Forwards protection subject to the new instance
        def build_record_with_protector(*args)
          return build_record_without_protector(*args) unless protector_subject?
          build_record_without_protector(*args).restrict!(protector_subject)
        end
      end
    end
  end
end
