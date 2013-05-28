require 'protector/adapters/active_record/base'
require 'protector/adapters/active_record/association'
require 'protector/adapters/active_record/relation'

module Protector
  module Adapters
    module ActiveRecord
      def self.activate!
        ::ActiveRecord::Base.send :include, Protector::Adapters::ActiveRecord::Base
        ::ActiveRecord::Relation.send :include, Protector::Adapters::ActiveRecord::Relation
        ::ActiveRecord::Associations::SingularAssociation.send :include, Protector::Adapters::ActiveRecord::Association
        ::ActiveRecord::Associations::CollectionAssociation.send :include, Protector::Adapters::ActiveRecord::Association
        # ::ActiveRecord::Associations::Preloader::Association.send :include, Protector::Adapters::ActiveRecord::PreloaderAssociation
      end
    end
  end
end