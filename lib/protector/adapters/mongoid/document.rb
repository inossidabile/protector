module Protector
  module Adapters
    module Mongoid
      module Document
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
          include Protector::DSL::Entry

          ObjectSpace.each_object(Class).each do |klass|
            klass.protector_redefine_fields if klass < self
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

          def restrict!(*args)
            @protector_meta = nil
            super
          end

          def self.restrict!(*args)
            all.restrict! *args
          end
        end

        module ClassMethods
          # Storage of {Protector::DSL::Meta}
          def protector_meta
            @protector_meta ||= Protector::DSL::Meta.new(
              Protector::Adapters::Mongoid,
              self,
              self.fields.keys
            )
          end
        end

        # Storage for {Protector::DSL::Meta::Box}
        def protector_meta(subject=protector_subject)
          @protector_meta ||= self.class.protector_meta.evaluate(subject, self)
        end

        # Checks if current model can be selected in the context of current subject
        def visible?
          return true unless protector_meta.scoped?

          protector_meta.relation.where(:_id => id).any?
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

        # methods of Mongoid::Fields

        module ClassMethods
          def protector_redefine_fields
            self.fields.each do |name, field|
              create_accessors name, name, field.options
              create_dirty_methods name, name
            end

            self.aliased_fields.each do |aliased, name|
              field = self.fields[name]

              create_accessors name, aliased, field.options
              create_dirty_methods name, aliased
            end
          end

          def protector_wrap_getter(name)
            generated_methods.class_eval <<-EVAL, __FILE__, __LINE__ + 1
              alias_method #{"#{name}_unprotected".inspect}, #{name.inspect}

              def #{name}
                if !protector_subject? || protector_meta.readable?(#{name.inspect})
                  #{name}_unprotected
                else
                  nil
                end
              end
            EVAL
          end

          def create_field_getter(name, meth, field)
            super

            protector_wrap_getter name unless name == '_id'
          end

          def create_field_getter_before_type_cast(name, meth)
            super

            protector_wrap_getter "#{name}_before_type_cast" unless name == "_id"
          end

          def create_field_check(name, meth)
            super

            generated_methods.class_eval <<-EVAL, __FILE__, __LINE__ + 1
              alias_method #{"#{name}_unprotected?".inspect}, #{"#{name}?".inspect}

              def #{name}?
                if !protector_subject? || protector_meta.readable?(#{name.inspect})
                  #{name}_unprotected?
                else
                  false
                end
              end
            EVAL
          end
        end
      end
    end
  end
end
