require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'appraisal'

RSpec::Core::RakeTask.new(:spec)

task :default => :all

desc 'Test the plugin under all supported Rails versions.'
task :all => ["appraisal:install"] do |t|
  exec('rake appraisal spec')
end

task :perf do
  require 'protector'

  Bundler.require

  %w(ActiveRecord DataMapper Mongoid Sequel).each do |a|
    if (a.constantize rescue nil)
      load "perf/perf_helpers/boot.rb"
      Perf.load a.underscore
    end
  end
end