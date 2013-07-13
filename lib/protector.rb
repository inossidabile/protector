require "active_support/all"
require "i18n"

require "protector/version"
require "protector/dsl"
require "protector/adapters/active_record"
require "protector/adapters/sequel"

require "protector/engine" if defined?(Rails)

I18n.load_path += Dir[File.expand_path File.join('..', 'locales', '*.yml'), File.dirname(__FILE__)]

module Protector
  class << self
    ADAPTERS = [
      Protector::Adapters::ActiveRecord,
      Protector::Adapters::Sequel
    ]

    attr_accessor :config

    def paranoid=
      "`Protector.paranoid = ...` is deprecated! Please change it to `Protector.config.paranoid = ...`"
    end

    # Allows executing any code having Protector globally disabled
    def insecurely(&block)
      Thread.current[:protector_disabled] = true
      yield
    ensure
      Thread.current[:protector_disabled] = false
    end

    def activate!
      ADAPTERS.each{|adapter| adapter.activate!}
    end
  end

  self.config = ActiveSupport::OrderedOptions.new
end

Protector.activate!