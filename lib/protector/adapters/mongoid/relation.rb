module Protector
  module Adapters
    module Mongoid
      module Relation
        extend ActiveSupport::Concern
=begin
        included do
          class_eval <<-EVAL, __FILE__, __LINE__ + 1
            alias_method_chain :get_relation, :protector

            def get_relation_with_protector(*args)
              proxy = get_relation_without_protector(*args)
              proxy = proxy.restrict!(protector_subject) if protector_subject?
              proxy
            end
          EVAL
        end
=end
      end
    end
  end
end
