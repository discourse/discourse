# -*- encoding: utf-8 -*-
require File.expand_path('../lib/discourse_plugin/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Robin Ward"]
  gem.email         = ["robin.ward@gmail.com"]
  gem.description   = %q{Toolkit for creating a discourse plugin}
  gem.summary       = %q{Toolkit for creating a discourse plugin}
  gem.homepage      = ""

  # when this is extracted comment it back in, prd has no .git 
  # gem.files         = `git ls-files`.split($\)
  gem.files         = Dir['README*','LICENSE','lib/**/*.rb']

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "discourse_plugin"
  gem.require_paths = ["lib"]
  gem.version       = DiscoursePlugin::VERSION
end
