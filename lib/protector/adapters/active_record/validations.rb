module Protector
  module Adapters
    module ActiveRecord
      module Validations
        def valid?(*args)
          if protector_subject?
            state  = Protector.insecurely{ super(*args) }
            method = new_record? ? :first_uncreatable_field : :first_unupdatable_field
            field  = protector_meta.send(method, protector_changed)

            if field
              errors[:base] << I18n.t('protector.invalid', field: field)
              state = false
            end

            state
          else
            super(*args)
          end
        end
      end
    end
  end
end