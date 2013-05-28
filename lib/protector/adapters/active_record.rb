require 'protector/adapters/active_record/base'
require 'protector/adapters/active_record/association'
require 'protector/adapters/active_record/relation'
require 'protector/adapters/active_record/preloader'

module Protector
  module Adapters
    module ActiveRecord
      def self.activate!
        ::ActiveRecord::Base.send :include, Protector::Adapters::ActiveRecord::Base
        ::ActiveRecord::Relation.send :include, Protector::Adapters::ActiveRecord::Relation
        ::ActiveRecord::Associations::SingularAssociation.send :include, Protector::Adapters::ActiveRecord::Association
        ::ActiveRecord::Associations::CollectionAssociation.send :include, Protector::Adapters::ActiveRecord::Association
        ::ActiveRecord::Associations::Preloader.send :include, Protector::Adapters::ActiveRecord::Preloader
        ::ActiveRecord::Associations::Preloader::Association.send :include, Protector::Adapters::ActiveRecord::Preloader::Association
      end
    end
  end
end