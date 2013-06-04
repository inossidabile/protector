require "active_support/all"
require "i18n"

require "protector/version"
require "protector/dsl"
require "protector/adapters/active_record"
require "protector/adapters/sequel"

I18n.load_path += Dir[File.expand_path File.join('..', 'locales', '*.yml'), File.dirname(__FILE__)]

Protector::Adapters::ActiveRecord.activate! if defined?(ActiveRecord)
Protector::Adapters::Sequel.activate! if defined?(Sequel)