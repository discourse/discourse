# -*- encoding: utf-8 -*-
# stub: unix-crypt 1.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "unix-crypt"
  s.version = "1.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Roger Nesbitt"]
  s.date = "2013-12-11"
  s.description = "Performs the UNIX crypt(3) algorithm using DES (standard 13 character passwords), MD5 (starting with $1$), SHA256 (starting with $5$) and SHA512 (starting with $6$)"
  s.email = "roger@seriousorange.com"
  s.executables = ["mkunixcrypt"]
  s.files = ["bin/mkunixcrypt"]
  s.homepage = "https://github.com/mogest/unix-crypt"
  s.licenses = ["BSD"]
  s.rubygems_version = "2.5.1"
  s.summary = "Performs the UNIX crypt(3) algorithm using DES, MD5, SHA256 or SHA512"

  s.installed_by_version = "2.5.1" if s.respond_to? :installed_by_version
end
