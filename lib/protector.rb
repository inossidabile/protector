require "active_support/all"
require "i18n"

require "protector/version"
require "protector/dsl"
require "protector/adapters/active_record"
require "protector/adapters/sequel"

I18n.load_path += Dir[File.expand_path File.join('..', 'locales', '*.yml'), File.dirname(__FILE__)]

module Protector
  class << self
    ADAPTERS = [
      Protector::Adapters::ActiveRecord,
      Protector::Adapters::Sequel
    ]

    attr_accessor :paranoid

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
end

Protector.activate!