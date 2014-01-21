module Protector
  class Engine < ::Rails::Engine
    config.protector = ActiveSupport::OrderedOptions.new

    initializer 'protector.configuration' do |app|
      app.config.protector.each { |k, v| Protector.config[k] = v }

      if Protector::Adapters::ActiveRecord.modern?
        ::ActiveRecord::Base.send(:include, Protector::ActiveRecord::Adapters::StrongParameters)
      end
    end
  end
end
