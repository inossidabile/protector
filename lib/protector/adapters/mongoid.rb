require 'protector/adapters/mongoid/document'
require 'protector/adapters/mongoid/criteria'
require 'protector/adapters/mongoid/relation'

module Protector
  module Adapters
    module Mongoid
      def self.activate!
        return false unless defined?(::Mongoid::Document)

        ::Mongoid::Document.send :include, Protector::Adapters::Mongoid::Document
        ::Mongoid::Criteria.send :include, Protector::Adapters::Mongoid::Criteria
        # In uses Many criteria internally
        ::Mongoid::Relations::Accessors.send :include, Protector::Adapters::Mongoid::Relation
      end

      def self.is?(instance)
        instance.kind_of?(::Mongoid::Criteria) || instance < ::Mongoid::Document
      end

      def self.null_proc
        @null_proc ||= Proc.new{ where("false") }
      end
    end
  end
end