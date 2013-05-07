# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name        = "simple_handlebars_rails"
  s.version     = "0.0.1"
  s.authors     = ["Robin Ward"]
  s.email       = ["robin.ward@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Basic Mustache Support for Rails}
  s.description = %q{Adds the Mustache plugin and a corresponding Sprockets engine to the asset pipeline in Rails applications.}

  s.add_development_dependency "rails", ["> 3.1"]
  s.add_dependency 'rails', ['> 3.1']

  s.files = Dir["lib/**/*"]
  s.require_paths = ["lib"]
end
