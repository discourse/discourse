# -*- encoding: utf-8 -*-
require File.expand_path('../lib/discourse_task/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Robin Ward"]
  gem.email         = ["robin.ward@gmail.com"]
  gem.description   = %q{This gem add a Task archetype to discourse that can be closed}
  gem.summary       = %q{This gem add a Task archetype to discourse that can be closed}
  gem.homepage      = ""

  # when this is extracted comment it back in, prd has no .git 
  gem.files         = Dir['README*','LICENSE','lib/**/*.rb']

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "discourse_task"
  gem.require_paths = ["lib"]
  gem.version       = DiscourseTask::VERSION
end
