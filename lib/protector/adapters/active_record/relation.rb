module Protector
  module Adapters
    module ActiveRecord
      module Relation
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base

          alias_method_chain :exec_queries, :protector
        end

        def protector_meta
          @klass.protector_meta.evaluate(@klass, @klass.column_names, @protector_subject)
        end

        def unscoped
          super.restrict!(@protector_subject)
        end

        def count(*args)
          super || 0
        end

        def sum(*args)
          super || 0
        end

        def calculate(*args)
          return super unless @protector_subject
          merge(protector_meta.relation).unrestrict!.calculate *args
        end

        def exists?(*args)
          return super unless @protector_subject
          merge(protector_meta.relation).unrestrict!.exists? *args
        end

        def exec_queries_with_protector(*args)
          return exec_queries_without_protector unless @protector_subject

          subject  = @protector_subject
          relation = merge(protector_meta.relation).unrestrict!
          @records = relation.send(:exec_queries).each{|r| r.restrict!(subject)}
        end
      end
    end
  end
end