module Protector
  class Engine < ::Rails::Engine
    config.protector = ActiveSupport::OrderedOptions.new

    initializer "protector.configuration" do |app|
      app.config.protector.each do |key, value|
        Protector.send "#{key}=", value
      end
    end
  end
end
