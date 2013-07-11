require 'protector/adapters/active_record/base'
require 'protector/adapters/active_record/association'
require 'protector/adapters/active_record/relation'
require 'protector/adapters/active_record/preloader'

module Protector
  module Adapters
    # ActiveRecord adapter
    module ActiveRecord
      # YIP YIP! Monkey-Patch the ActiveRecord.
      def self.activate!
        return false unless defined?(::ActiveRecord)

        ::ActiveRecord::Base.send :include, Protector::Adapters::ActiveRecord::Base
        ::ActiveRecord::Relation.send :include, Protector::Adapters::ActiveRecord::Relation
        ::ActiveRecord::Associations::SingularAssociation.send :include, Protector::Adapters::ActiveRecord::Association
        ::ActiveRecord::Associations::CollectionAssociation.send :include, Protector::Adapters::ActiveRecord::Association
        ::ActiveRecord::Associations::Preloader.send :include, Protector::Adapters::ActiveRecord::Preloader
        ::ActiveRecord::Associations::Preloader::Association.send :include, Protector::Adapters::ActiveRecord::Preloader::Association
      end

      def self.modern?
        Gem::Version.new(::ActiveRecord::VERSION::STRING) >= Gem::Version.new('4.0.0')
      end

      def self.is?(instance)
        instance.is_a?(::ActiveRecord::Relation) ||
        (instance.is_a?(Class) && instance < ActiveRecord::Base)
      end

      def self.nullify(relation)
        if modern?
          relation.none
        else
          relation.where("1=0")
        end
      end
    end
  end
end