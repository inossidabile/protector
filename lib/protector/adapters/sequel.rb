require 'protector/adapters/sequel/model'
require 'protector/adapters/sequel/dataset'
require 'protector/adapters/sequel/eager_graph_loader'

module Protector
  module Adapters
    # Sequel adapter
    module Sequel
      # YIP YIP! Monkey-Patch the Sequel.
      def self.activate!
        ::Sequel::Model.send :include, Protector::Adapters::Sequel::Model
        ::Sequel::Dataset.send :include, Protector::Adapters::Sequel::Dataset
        ::Sequel::Model::Associations::EagerGraphLoader.send :include, Protector::Adapters::Sequel::EagerGraphLoader
      end
    end
  end
end