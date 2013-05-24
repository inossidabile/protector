require "active_support/all"

require "protector/version"
require "protector/dsl"
require "protector/adapters/active_record"

I18n.load_path << Dir[File.join File.expand_path(File.dirname(__FILE__)), '..', 'locales', '*.yml']

Protector::Adapters::ActiveRecord.activate! if defined?(ActiveRecord)