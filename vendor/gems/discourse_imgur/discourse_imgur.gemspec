# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'discourse_imgur/version'

Gem::Specification.new do |spec|
  spec.name          = "discourse_imgur"
  spec.version       = DiscourseImgur::VERSION
  spec.authors       = ["Régis Hanol"]
  spec.email         = ["regis@hanol.fr"]
  spec.description   = %q{Add support for Imgur}
  spec.summary       = %q{Add support for Imgur}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
