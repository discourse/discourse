# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'discourse/oneboxer/version'

Gem::Specification.new do |spec|
  spec.name          = "discourse-oneboxer"
  spec.version       = Discourse::Oneboxer::VERSION
  spec.authors       = ["Joanna Zeta", "Vyki Englert"]
  spec.email         = ["holla@jzeta.com", "vyki.englert@gmail.com"]
  spec.description   = %q{A gem for turning URLs into previews.}
  spec.summary       = spec.description
  spec.homepage      = "http://github.com/dysania/discourse-oneboxer"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "multi_json"
  spec.add_runtime_dependency "mustache"
  spec.add_runtime_dependency "nokogiri"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "fakeweb"
  spec.add_development_dependency "pry"
end
