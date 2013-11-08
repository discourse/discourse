# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omniauth/lessonplanet/version'

Gem::Specification.new do |spec|
  spec.name          = 'omniauth-lessonplanet'
  spec.version       = Omniauth::Lessonplanet::VERSION
  spec.authors       = ['Lesson Planet Devs']
  spec.email         = ['devs@lessonplanet.com']
  spec.description   = %q{OmniAuth strategy for Lesson Planet}
  spec.summary       = %q{OmniAuth strategy for Lesson Planet}

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency 'omniauth', '~> 1.0'
  spec.add_runtime_dependency 'omniauth-oauth2'
end
