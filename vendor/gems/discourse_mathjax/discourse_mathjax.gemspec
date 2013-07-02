# -*- encoding: utf-8 -*-
require File.expand_path('../lib/discourse_mathjax/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["David Montoya"]
  gem.email         = ["masda70@gmail.com"]
  gem.description   = %q{This gem adds mathjax support to discourse}
  gem.summary       = %q{This gem adds mathjax support to discourse}
  gem.homepage      = ""

  # when this is extracted comment it back in, prd has no .git 
  gem.files         = Dir['README*','LICENSE','lib/**/*.rb']

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "discourse_mathjax"
  gem.require_paths = ["lib"]
  gem.version       = DiscourseMathjax::VERSION
end
