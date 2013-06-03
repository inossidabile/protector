module Protector
  module Adapters
    module Sequel
      # Patches `Sequel::Model`
      module Model
        extend ActiveSupport::Concern

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
          # Gets default restricted `Dataset`
          def restrict!(subject)
            dataset.clone.restrict! subject
          end
        end

        # Storage for {Protector::DSL::Meta::Box}
        def protector_meta
          unless @protector_subject
            raise "Unprotected entity detected: use `restrict` method to protect it."
          end

          @protector_meta ||= self.class.protector_meta.evaluate(
            self.class,
            @protector_subject,
            self.class.columns,
            self
          )
        end

        # Checks if current model can be selected in the context of current subject
        def visible?
          protector_meta.relation.where(pk_hash).any?
        end

        # Checks if current model can be created in the context of current subject
        def creatable?
          fields = HashWithIndifferentAccess[keys.map{|x| [x.to_s, @values[x]]}]
          protector_meta.creatable?(fields)
        end

        # Checks if current model can be updated in the context of current subject
        def updatable?
          fields = HashWithIndifferentAccess[changed_columns.map{|x| [x.to_s, @values[x]]}]
          protector_meta.updatable?(fields)
        end

        # Checks if current model can be destroyed in the context of current subject
        def destroyable?
          protector_meta.destroyable?
        end

        # Basic security validations
        def validate
          super
          return unless @protector_subject
          method = new? ? :creatable? : :updatable?
          errors.add(:base, I18n.t('protector.invalid')) unless __send__(method)
        end

        # Destroy availability check
        def before_destroy
          return false if @protector_subject && !destroyable?
          super
        end

        # Security-checking attributes reader
        #
        # @param name [Symbol]          Name of attribute to read
        def [](name)
          if (
            !@protector_subject || 
            name == self.class.primary_key ||
            (self.class.primary_key.is_a?(Array) && self.class.primary_key.include?(name)) ||
            protector_meta.readable?(name.to_s)
          )
            @values[name]
          else
            nil
          end
        end

        # This is used whenever we fetch data
        def _associated_dataset(*args)
          super.restrict!(@protector_subject)
        end

        # This is used whenever we call counters and existance checkers
        def _dataset(*args)
          super.restrict!(@protector_subject)
        end
      end
    end
  end
end