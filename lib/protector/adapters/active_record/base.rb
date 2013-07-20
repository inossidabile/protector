module Protector
  module Adapters
    module ActiveRecord
      # Patches `ActiveRecord::Base`
      module Base
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
          include Protector::DSL::Entry

          # We need this to make sure no ActiveRecord classes managed
          # to cache db scheme and create corresponding methods since
          # we want to modify the way they get created
          ObjectSpace.each_object(Class).each do |klass|
            klass.undefine_attribute_methods if klass < self
          end

          validate do
            return unless protector_subject?
            if (new_record? && !creatable?) || (!new_record? && !updatable?)
              errors[:base] << I18n.t('protector.invalid')
            end
          end

          before_destroy do
            return true unless protector_subject?
            destroyable?
          end

          # Drops {Protector::DSL::Meta::Box} cache when subject changes
          def restrict!(*args)
            @protector_meta = nil
            super
          end

          unless Protector::Adapters::ActiveRecord.modern?
            def self.restrict!(*args)
              scoped.restrict! *args
            end
          else
            def self.restrict!(*args)
              all.restrict! *args
            end
          end

          def [](name)
            if (
              !protector_subject? || 
              name == self.class.primary_key ||
              (self.class.primary_key.is_a?(Array) && self.class.primary_key.include?(name)) ||
              protector_meta.readable?(name)
            )
              read_attribute(name)
            else
              nil
            end
          end
        end

        module ClassMethods
          # Storage of {Protector::DSL::Meta}
          def protector_meta
            @protector_meta ||= Protector::DSL::Meta.new(
              Protector::Adapters::ActiveRecord,
              self,
              self.column_names
            )
          end

          # Wraps every `.field` method with a check against {Protector::DSL::Meta::Box#readable?}
          def define_method_attribute(name)
            super

            # Show some <3 to composite primary keys
            unless (primary_key == name || Array(primary_key).include?(name))
              generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
                alias_method #{"#{name}_unprotected".inspect}, #{name.inspect}

                def #{name}
                  if !protector_subject? || protector_meta.readable?(#{name.inspect})
                    #{name}_unprotected
                  else
                    nil
                  end
                end
              STR
            end
          end
        end

        # Storage for {Protector::DSL::Meta::Box}
        def protector_meta(subject=protector_subject)
          @protector_meta ||= self.class.protector_meta.evaluate(subject, self)
        end

        # Checks if current model can be selected in the context of current subject
        def visible?
          return true unless protector_meta.scoped?

          protector_meta.relation.where(
            self.class.primary_key => id
          ).any?
        end

        # Checks if current model can be created in the context of current subject
        def creatable?
          fields = HashWithIndifferentAccess[changed.map{|field| [field, read_attribute(field)]}]
          protector_meta.creatable?(fields)
        end

        # Checks if current model can be updated in the context of current subject
        def updatable?
          fields = HashWithIndifferentAccess[changed.map{|field| [field, read_attribute(field)]}]
          protector_meta.updatable?(fields)
        end

        # Checks if current model can be destroyed in the context of current subject
        def destroyable?
          protector_meta.destroyable?
        end

        def can?(action, field=false)
          protector_meta.can?(action, field)
        end
      end
    end
  end
end