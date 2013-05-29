Bundler.require

require 'protector'
require_relative 'examples/model'

module ProtectionTester
  extend ActiveSupport::Concern

  included do
    protect do |x|
      scope{ where('1=0') } if x == '-'
      scope{ where(number: 999) } if x == '+' 

      can :view, :dummy_id unless x == '-'
    end
  end
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end