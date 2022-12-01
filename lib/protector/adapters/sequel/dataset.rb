module Protector
  module Adapters
    module Sequel
      # Patches `Sequel::Dataset`
      module Dataset extend ActiveSupport::Concern

        # Wrapper for the Dataset `row_proc` adding restriction function
        class Restrictor
          attr_accessor :subject
          attr_accessor :mutator

          def initialize(subject, mutator)
            @subject = subject
            @mutator = mutator
          end

          # Mutate entity through `row_proc` if available and then protect
          #
          # @param entity [Object]          Entity coming from Dataset
          def call(entity)
            entity = mutator.call(entity) if mutator
            return entity unless entity.respond_to?(:restrict!)
            entity.restrict!(@subject)
          end
        end

        included do |klass|
          include Protector::DSL::Base

          alias_method :each_without_protector, :each
          alias_method :each, :each_with_protector
        end

        def creatable?
          model.new.restrict!(protector_subject).creatable?
        end

        def can?(action, field=false)
          protector_meta.can?(action, field)
        end

        # Gets {Protector::DSL::Meta::Box} of this dataset
        def protector_meta(subject=protector_subject)
          model.protector_meta.evaluate(subject)
        end

        # Substitutes `row_proc` with {Protector} and injects protection scope
        def each_with_protector(*args, &block)
          return each_without_protector(*args, &block) unless protector_subject?

          relation = protector_defend_graph(clone, protector_subject)
          relation = protector_meta.eval_scope_procs(relation) if protector_meta.scoped?

          relation.row_proc = Restrictor.new(protector_subject, relation.row_proc)
          relation.each_without_protector(*args, &block)
        end

        # Injects protection scope for every joined graph association
        def protector_defend_graph(relation, subject)
          return relation unless @opts[:eager_graph]

          @opts[:eager_graph][:reflections].each do |association, reflection|
            model = reflection[:cache][:class] if reflection[:cache].is_a?(Hash) && reflection[:cache][:class]
            model = reflection[:class_name].constantize unless model
            meta  = model.protector_meta.evaluate(subject)

            relation = meta.eval_scope_procs(relation) if meta.scoped?
          end

          relation
        end
      end
    end
  end
end
