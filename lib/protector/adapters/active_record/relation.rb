module Protector
  module Adapters
    module ActiveRecord
      
      # Pathces `ActiveRecord::Relation`
      module Relation
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base

          alias_method_chain :exec_queries, :protector
          alias_method_chain :eager_loading?, :protector

          attr_accessor :eager_loadable_when_protected

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

        # Gets {Protector::DSL::Meta::Box} of this relation
        def protector_meta
          # We don't seem to require columns here as well
          # @klass.protector_meta.evaluate(@klass, @protector_subject, @klass.column_names)
          @klass.protector_meta.evaluate(@klass, @protector_subject)
        end

        # @note Unscoped relation drops properties and therefore should be re-restricted
        def unscoped
          super.restrict!(@protector_subject)
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
          return super unless @protector_subject
          merge(protector_meta.relation).unrestrict!.calculate *args
        end

        # Merges current relation with restriction and calls real `exists?`
        def exists?(*args)
          return super unless @protector_subject
          merge(protector_meta.relation).unrestrict!.exists? *args
        end

        # Patches current relation to fulfill restriction and call real `exec_queries`
        #
        # Patching includes:
        #
        # * turning `includes` into `preload`
        # * delaying built-in preloading to the stage where selection is restricted
        # * merging current relation with restriction
        def exec_queries_with_protector(*args)
          return exec_queries_without_protector unless @protector_subject

          subject  = @protector_subject
          relation = merge(protector_meta.relation).unrestrict!

          relation = protector_substitute_includes(relation)

          # We should explicitly allow/deny eager loading now that we know
          # if we can use it
          relation.eager_loadable_when_protected = relation.includes_values.any?

          # Preserve associations from internal loading. We are going to handle that
          # ourselves respecting security scopes FTW!
          associations, relation.preload_values = relation.preload_values, []

          @records = relation.send(:exec_queries).each{|r| r.restrict!(subject)}

          # Now we have @records restricted properly so let's preload associations!
          associations.each do |a|
            ::ActiveRecord::Associations::Preloader.new(@records, a).run
          end

          @loaded = true
          @records
        end

        # Swaps `includes` with `preload` and adds JOINs to any table referenced
        # from `where` (or manually with `reference`)
        def protector_substitute_includes(relation)
          subject = @protector_subject

          # Note that `includes_values` shares reference across relation diffs so
          # it can not be modified safely and should be copied instead
          includes, relation.includes_values = relation.includes_values, []

          # We can not allow join-based eager loading for scoped associations
          # since actual filtering can differ for host model and joined relation.
          # Therefore we turn all `includes` into `preloads`.
          includes.each do |iv|
            protector_expand_include(iv).each do |ive|
              # First-level associations can stay JOINed if restriction scope
              # is absent. Checking deep associations would make us to check
              # every parent. This should probably be done sometimes :\
              meta = ive[0].protector_meta.evaluate(ive[0], subject) unless ive[1].is_a?(Hash)

              # We leave unscoped restrictions as `includes`
              # but turn scoped ones into `preloads`
              if meta && !meta.scoped?
                relation.includes!(ive[1])
              else
                if relation.references_values.include?(ive[0].table_name)
                  if relation.respond_to?(:joins!)
                    relation.joins!(ive[1])
                  else
                    relation = relation.joins(ive[1])
                  end
                end

                # AR 3.2 Y U NO HAVE BANG RELATION MODIFIERS
                relation.preload_values << ive[1]
                false
              end
            end
          end

          relation
        end

        # Checks whether current object can be eager loaded respecting
        # protector flags
        def eager_loading_with_protector?
          flag = eager_loading_without_protector?
          flag &&= !!@eager_loadable_when_protected unless @eager_loadable_when_protected.nil?
          flag
        end

        # Indexes `includes` format by actual entity class
        #
        # Turns `{foo: :bar}` into `[[Foo, :foo], [Bar, {foo: :bar}]`
        #
        # @param [Symbol, Array, Hash] inclusion        Inclusion description in the AR format
        # @param [Array] results                        Resulting set
        # @param [Array] base                           Association path ([:foo, :bar])
        # @param [Class] klass                          Base class
        def protector_expand_include(inclusion, results=[], base=[], klass=@klass)
          if inclusion.is_a?(Hash)
            protector_expand_include_hash(inclusion, results, base, klass)
          else
            Array(inclusion).each do |i|
              if i.is_a?(Hash)
                protector_expand_include_hash(i, results, base, klass)
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

        def protector_expand_include_hash(inclusion, results=[], base=[], klass=@klass)
          inclusion.each do |key, value|
            model = klass.reflect_on_association(key.to_sym).klass
            value = [value] unless value.is_a?(Array)
            nest  = [key]+base

            value.each do |v|
              if v.is_a?(Hash)
                protector_expand_include_hash(v, results, nest)
              else
                results << [
                  model.reflect_on_association(v.to_sym).klass,
                  nest.inject(v){|a, n| { n => a } }
                ]
              end
            end

            results << [model, base.inject(key){|a, n| { n => a } }]
          end
        end
      end
    end
  end
end