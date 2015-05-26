module Protector
  module Adapters
    module ActiveRecord
      # Patches `ActiveRecord::Relation`
      module Relation
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base

          alias_method_chain :exec_queries, :protector
          alias_method_chain :new, :protector
          alias_method_chain :create, :protector
          alias_method_chain :create!, :protector

          # AR 3.2 workaround. Come on, guys... SQL parsing :(
          unless method_defined?(:references_values)
            def references_values
              tables_in_string(to_sql)
            end
          end

          unless method_defined?(:includes!)
            def includes!(*args)
              self.includes_values += args
              self
            end
          end
        end

        def creatable?
          new.creatable?
        end

        def can?(action, field=false)
          protector_meta.can?(action, field)
        end

        # Gets {Protector::DSL::Meta::Box} of this relation
        def protector_meta(subject=protector_subject)
          @klass.protector_meta.evaluate(subject)
        end

        def protector_relation
          result = self.clone
          result = protector_meta.eval_scope_procs(result) if protector_meta.relation
          result
        end

        # @note Unscoped relation drops properties and therefore should be re-restricted
        def unscoped
          return super unless protector_subject?
          super.restrict!(protector_subject)
        end

        def except(*args)
          return super unless protector_subject?
          super.restrict!(protector_subject)
        end

        def only(*args)
          return super unless protector_subject?
          super.restrict!(protector_subject)
        end

        # @note This is here cause `NullRelation` can return `nil` from `count`
        def count(*args)
          super || 0
        end

        # @note This is here cause `NullRelation` can return `nil` from `sum`
        def sum(*args)
          super || 0
        end

        # Merges current relation with restriction and calls real `calculate`
        def calculate(*args)
          return super unless protector_subject?
          protector_relation.unrestrict!.calculate(*args)
        end

        # Merges current relation with restriction and calls real `exists?`
        def exists?(*args)
          return super unless protector_subject?
          protector_relation.unrestrict!.exists?(*args)
        end

        # Forwards protection subject to the new instance
        def new_with_protector(*args, &block)
          return new_without_protector(*args, &block) unless protector_subject?

          protector_permit_strong_params(args)

          unless block_given?
            new_without_protector(*args).restrict!(protector_subject)
          else
            new_without_protector(*args) do |instance|
              block.call instance.restrict!(protector_subject)
            end
          end
        end

        def create_with_protector(*args, &block)
          return create_without_protector(*args, &block) unless protector_subject?

          protector_permit_strong_params(args)

          create_without_protector(*args) do |instance|
            instance.restrict!(protector_subject)
            block.call(instance) if block
          end
        end

        def create_with_protector!(*args, &block)
          return create_without_protector!(*args, &block) unless protector_subject?

          protector_permit_strong_params(args)

          create_without_protector!(*args) do |instance|
            instance.restrict!(protector_subject)
            block.call(instance) if block
          end
        end

        # Patches current relation to fulfill restriction and call real `exec_queries`
        #
        # Patching includes:
        #
        # * turning `includes` (that are not referenced for eager loading) into `preload`
        # * delaying built-in preloading to the stage where selection is restricted
        # * merging current relation with restriction (of self and every eager association)
        def exec_queries_with_protector(*args)
          return @records if loaded?
          return exec_queries_without_protector unless protector_subject?

          subject  = protector_subject
          relation = protector_relation.unrestrict!
          relation = protector_substitute_includes(subject, relation)

          # Preserve associations from internal loading. We are going to handle that
          # ourselves respecting security scopes FTW!
          relation = relation.clone
          associations, relation.preload_values = relation.preload_values, []

          @records = relation.send(:exec_queries).each { |record| record.restrict!(subject) }

          # Now we have @records restricted properly so let's preload associations!
          associations.each do |association|
            if ::ActiveRecord::Associations::Preloader.method_defined? :preload
              ::ActiveRecord::Associations::Preloader.new.preload(@records, association)
            else
              ::ActiveRecord::Associations::Preloader.new(@records, association).run
            end
          end

          @loaded = true
          @records
        end

        # Swaps `includes` with `preload` if it's not referenced or merges
        # security scope of proper class otherwise
        def protector_substitute_includes(subject, relation)
          if relation.eager_loading?
            protector_expand_inclusion(relation.includes_values + relation.eager_load_values).each do |klass, path|
              # AR drops default_scope for eagerly loadable associations
              # https://github.com/inossidabile/protector/issues/3
              # and so should we
              meta = klass.protector_meta.evaluate(subject)

              if meta.scoped?
                unscoped = klass.unscoped

                # `unscoped` gets us a relation but Protector scope is supposed
                # to work with AR::Base. Some versions of AR have those uncompatible
                # so we have to workaround it :(
                unscoped.protector_mimic_base!

                # Finally we merge unscoped basic relation extended with protection scope
                relation = relation.merge meta.eval_scope_procs(unscoped)
              end
            end
          else
            relation = relation.clone
            relation.preload_values += includes_values
            relation.includes_values = []
          end

          relation
        end

        # Makes instance of Relation duck-type compatible to AR::Base to allow proper
        # protection block execution with itself
        def protector_mimic_base!
          return unless Protector::Adapters::ActiveRecord.modern?

          class <<self
            # AR 4 has awfull inconsistency when it comes to method `all`
            # We have to mimic base class behaviour for relation we get from `unscoped`
            def all
              self
            end
          end
        end

        # Indexes `includes` format by actual entity class
        #
        # Turns `{foo: :bar}` into `[[Foo, :foo], [Bar, {foo: :bar}]`
        #
        # @param [Symbol, Array, Hash] inclusion        Inclusion description in the AR format
        # @param [Array] results                        Resulting set
        # @param [Array] base                           Association path ([:foo, :bar])
        # @param [Class] klass                          Base class
        def protector_expand_inclusion(inclusion, results=[], base=[], klass=@klass)
          if inclusion.is_a?(Hash)
            protector_expand_inclusion_hash(inclusion, results, base, klass)
          else
            Array(inclusion).each do |i|
              if i.is_a?(Hash)
                protector_expand_inclusion_hash(i, results, base, klass)
              else
                results << [
                  klass.reflect_on_association(i.to_sym).klass,
                  i.to_sym
                ]
              end
            end
          end

          results
        end

        private

        def protector_permit_strong_params(args)
          # strong_parameters integration
          if Protector.config.strong_parameters? && args.first.respond_to?(:permit)
            Protector::ActiveRecord::Adapters::StrongParameters.sanitize! args, true, protector_meta
          end
        end


        def protector_expand_inclusion_hash(inclusion, results=[], base=[], klass=@klass)
          inclusion.each do |key, value|
            model = klass.reflect_on_association(key.to_sym).klass
            value = [value] unless value.is_a?(Array)
            nest  = [key] + base

            value.each do |v|
              if v.is_a?(Hash)
                protector_expand_inclusion_hash(v, results, nest)
              else
                results << [
                  model.reflect_on_association(v.to_sym).klass,
                  nest.reduce(v) { |a, n| { n => a } }
                ]
              end
            end

            results << [model, base.reduce(key) { |a, n| { n => a } }]
          end
        end
      end
    end
  end
end
