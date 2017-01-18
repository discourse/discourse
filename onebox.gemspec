# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'onebox/version'

Gem::Specification.new do |spec|
  spec.name          = 'onebox'
  spec.version       = Onebox::VERSION
  spec.authors       = ['Joanna Zeta', 'Vyki Englert', 'Robin Ward']
  spec.email         = ['holla@jzeta.com', 'vyki.englert@gmail.com', 'robin.ward@gmail.com']
  spec.description   = %q{A gem for turning URLs into previews.}
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/discourse/onebox'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'multi_json', '~> 1.11'
  spec.add_runtime_dependency 'mustache'
  spec.add_runtime_dependency 'nokogiri', '~> 1.6.6'
  spec.add_runtime_dependency 'moneta', '~> 0.8'
  spec.add_runtime_dependency 'htmlentities', '~> 4.3.4'
  spec.add_runtime_dependency 'fast_blank', '>= 1.0.0'
  spec.add_runtime_dependency 'sanitize'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.4'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'yard', '~> 0.8'
  spec.add_development_dependency 'fakeweb', '~> 1.3'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'mocha', '~> 1.1'
  spec.add_development_dependency 'rubocop', '~> 0.30'
  spec.add_development_dependency 'twitter', '~> 4.8'
  spec.add_development_dependency 'guard-rspec', '~> 4.2.8'
  spec.add_development_dependency 'sinatra', '~> 1.4'
  spec.add_development_dependency 'sinatra-contrib', '~> 1.4'
  spec.add_development_dependency 'haml', '~> 4.0'
  spec.add_development_dependency 'listen', '~> 2.10.0'
end
