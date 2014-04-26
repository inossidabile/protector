module Protector
  module Adapters
    module Sequel
      # Patches `Sequel::Model`
      module Model extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
          include Protector::DSL::Entry

          # Drops {Protector::DSL::Meta::Box} cache when subject changes
          def restrict!(*args)
            @protector_meta = nil
            super
          end
        end

        module ClassMethods
          # Storage of {Protector::DSL::Meta}
          def protector_meta
            ensure_protector_meta!(Protector::Adapters::Sequel) do
              columns
            end
          end

          # Gets default restricted `Dataset`
          def restrict!(*args)
            dataset.clone.restrict!(*args)
          end
        end

        # Gathers real values of given fields bypassing restrictions
        def protector_changed(fields)
          HashWithIndifferentAccess[fields.map { |x| [x.to_s, @values[x]] }]
        end

        # Storage for {Protector::DSL::Meta::Box}
        def protector_meta(subject=protector_subject)
          @protector_meta ||= self.class.protector_meta.evaluate(subject, self)
        end

        # Checks if current model can be selected in the context of current subject
        def visible?
          return true unless protector_meta.scoped?
          protector_meta.relation.where(pk_hash).any?
        end

        # Checks if current model can be created in the context of current subject
        def creatable?
          protector_meta.creatable? protector_changed(keys)
        end

        # Checks if current model can be updated in the context of current subject
        def updatable?
          protector_meta.updatable? protector_changed(changed_columns)
        end

        # Checks if current model can be destroyed in the context of current subject
        def destroyable?
          protector_meta.destroyable?
        end

        def can?(action, field=false)
          protector_meta.can?(action, field)
        end

        # Basic security validations
        def validate
          super
          return unless protector_subject?

          # rubocop:disable IndentationWidth, EndAlignment
          field = if new?
            protector_meta.first_uncreatable_field protector_changed(keys)
          else
            protector_meta.first_unupdatable_field protector_changed(changed_columns)
          end
          # rubocop:enable IndentationWidth, EndAlignment

          errors.add :base, I18n.t('protector.invalid', field: field) if field
        end

        # Destroy availability check
        def before_destroy
          return false if protector_subject? && !destroyable?
          super
        end

        # Security-checking attributes reader
        #
        # @param name [Symbol]          Name of attribute to read
        def [](name)
          # rubocop:disable ParenthesesAroundCondition
          if (
            !protector_subject? ||
            name == self.class.primary_key ||
            (self.class.primary_key.is_a?(Array) && self.class.primary_key.include?(name)) ||
            protector_meta.readable?(name.to_s)
          )
            @values[name.to_sym]
          else
            nil
          end
          # rubocop:enable ParenthesesAroundCondition
        end

        # This is used whenever we fetch data
        def _associated_dataset(*args)
          return super unless protector_subject?
          super.restrict!(protector_subject)
        end

        # This is used whenever we call counters and existance checkers
        def _dataset(*args)
          return super unless protector_subject?
          super.restrict!(protector_subject)
        end
      end
    end
  end
end
