module Protector
  module Adapters
    module Mongoid
      module Criteria
        extend ActiveSupport::Concern

        included do
          include Protector::DSL::Base
        end

        # Gets {Protector::DSL::Meta::Box} of this relation
        def protector_meta(subject=protector_subject)
          @klass.protector_meta.evaluate(subject)
        end

      end
    end
  end
end
