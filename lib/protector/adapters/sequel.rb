require 'protector/adapters/sequel/model'
require 'protector/adapters/sequel/dataset'

module Protector
  module Adapters
    # Sequel adapter
    module Sequel
      # YIP YIP! Monkey-Patch the Sequel.
      def self.activate!
        ::Sequel::Model.send :include, Protector::Adapters::Sequel::Model
        ::Sequel::Dataset.send :include, Protector::Adapters::Sequel::Dataset
      end
    end
  end
end