# frozen-string-literal: true

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'onebox/version'

Gem::Specification.new do |spec|
  spec.name          = 'onebox'
  spec.version       = Onebox::VERSION
  spec.authors       = ['Joanna Zeta', 'Vyki Englert', 'Robin Ward']
  spec.email         = ['holla@jzeta.com', 'vyki.englert@gmail.com', 'robin.ward@gmail.com']
  spec.description   = %q{A gem for generating embeddable HTML previews from URLs.}
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/discourse/onebox'
  spec.license       = 'MIT'

  # specs are too heavy to include they have tons of big fixtures
  # Git repo link exists so you can download from there
  spec.files         = `git ls-files`.split($/).reject { |s| s =~ /^(spec|web)/ }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'addressable', '~> 2.7.0'
  spec.add_runtime_dependency 'multi_json', '~> 1.11'
  spec.add_runtime_dependency 'mustache'
  spec.add_runtime_dependency 'nokogiri', '~> 1.7'
  spec.add_runtime_dependency 'htmlentities', '~> 4.3'
  spec.add_runtime_dependency 'sanitize'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'fakeweb', '~> 1.3'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'mocha', '~> 1.1'
  spec.add_development_dependency 'rubocop-discourse', '~> 2.4.0'
  spec.add_development_dependency 'twitter', '~> 4.8'
  spec.add_development_dependency 'guard-rspec', '~> 4.2.8'
  spec.add_development_dependency 'sinatra', '~> 1.4'
  spec.add_development_dependency 'sinatra-contrib', '~> 1.4'
  spec.add_development_dependency 'haml', '~> 5.1'
  spec.add_development_dependency 'listen', '~> 2.10.0'

  spec.required_ruby_version = '>=2.5.0'
end
