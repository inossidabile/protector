require 'simplecov'
require 'simplecov-summary'

SimpleCov.start do
  command_name File.basename(ENV['BUNDLE_GEMFILE'], '.gemfile')

  add_filter '/spec/'

  add_group 'DSL',          'lib/protector/dsl.rb'
  add_group 'Railtie',      'lib/protector/engine.rb'
  add_group 'ActiveRecord', 'lib/protector/adapters/active_record'
  add_group 'Sequel',       'lib/protector/adapters/sequel'

  at_exit do; end
end

Bundler.require

require_relative 'contexts/paranoid'
require_relative 'examples/model'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.after(:suite) do
    if SimpleCov.running
      silence_stream(STDOUT) do
        SimpleCov::Formatter::HTMLFormatter.new.format(SimpleCov.result)
      end

      SimpleCov::Formatter::SummaryFormatter.new.format(SimpleCov.result)
    end
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end