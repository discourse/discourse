# -*- encoding: utf-8 -*-
require File.expand_path('../lib/discourse_poll/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Robin Ward"]
  gem.email         = ["robin.ward@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  # when this is extracted comment it back in, prd has no .git 
  # gem.files         = `git ls-files`.split($\)
  gem.files         = Dir['README*','LICENSE','lib/**/*.rb']

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "discourse_poll"
  gem.require_paths = ["lib"]
  gem.version       = DiscoursePoll::VERSION
end
