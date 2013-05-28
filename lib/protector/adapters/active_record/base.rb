module Protector
  module Adapters
    module ActiveRecord
      module Base
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
          include Protector::DSL::Entry

          validate(on: :create) do
            return unless @protector_subject
            errors[:base] << I18n.t('protector.invalid') unless creatable?
          end

          validate(on: :update) do
            return unless @protector_subject
            errors[:base] << I18n.t('protector.invalid') unless updatable?
          end

          before_destroy do
            return true unless @protector_subject
            destroyable?
          end

          if Gem::Version.new(::ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0.0.rc1')
            def self.restrict!(subject)
              scoped.restrict!(subject)
            end
          else
            def self.restrict!(subject)
              all.restrict!(subject)
            end
          end

          def [](name)
            if !@protector_subject || name == self.class.primary_key || protector_meta.readable?(name)
              read_attribute(name)
            else
              nil
            end
          end
        end

        module ClassMethods
          def define_method_attribute(name)
            super

            # Show some <3 to composite primary keys
            unless (primary_key == name || Array(primary_key).include?(name))
              generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
                alias_method #{"#{name}_unprotected".inspect}, #{name.inspect}

                def #{name}
                  if !@protector_subject || protector_meta.readable?(#{name.inspect})
                    #{name}_unprotected
                  else
                    nil
                  end
                end
              STR
            end
          end
        end

        def protector_meta
          unless @protector_subject
            raise "Unprotected entity detected: use `restrict` method to protect it."
          end

          self.class.protector_meta.evaluate(
            self.class,
            @protector_subject,
            self.class.column_names,
            self
          )
        end

        def visible?
          protector_meta.relation.where(
            self.class.primary_key => id
          ).any?
        end

        def creatable?
          fields = HashWithIndifferentAccess[changed.map{|x| [x, read_attribute(x)]}]
          protector_meta.creatable?(fields)
        end

        def updatable?
          fields = HashWithIndifferentAccess[changed.map{|x| [x, read_attribute(x)]}]
          protector_meta.updatable?(fields)
        end

        def destroyable?
          protector_meta.destroyable?
        end
      end
    end
  end
end