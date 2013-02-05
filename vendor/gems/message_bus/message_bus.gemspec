# -*- encoding: utf-8 -*-
require File.expand_path('../lib/message_bus/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Sam Saffron"]
  gem.email         = ["sam.saffron@gmail.com"]
  gem.description   = %q{A message bus built on websockets}
  gem.summary       = %q{}
  gem.homepage      = ""

  # when this is extracted comment it back in, prd has no .git 
  # gem.files         = `git ls-files`.split($\)
  gem.files         = Dir['README*','LICENSE','lib/**/*.rb']
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "message_bus"
  gem.require_paths = ["lib"]
  gem.version       = MessageBus::VERSION
  gem.add_runtime_dependency 'rack', '>= 1.1.3'
  gem.add_runtime_dependency 'thin'
  gem.add_runtime_dependency 'eventmachine'
  gem.add_runtime_dependency 'redis'
end
