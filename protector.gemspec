# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'protector/version'

Gem::Specification.new do |spec|
  spec.name          = "protector"
  spec.version       = Protector::VERSION
  spec.authors       = ["Boris Staal"]
  spec.email         = ["boris@staal.io"]
  spec.description   = %q{Comfortable (seriously) white-list security restrictions for models on a field level}
  spec.summary       = %q{Protector is a successor to the Heimdallr gem: it hits the same goals keeping the Ruby way}
  spec.homepage      = "https://github.com/inossidabile/protector"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
