lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'unix_crypt'

spec = Gem::Specification.new do |s|
  s.name         = 'unix-crypt'
  s.version      = UnixCrypt::VERSION
  s.summary      = "Performs the UNIX crypt(3) algorithm using DES, MD5, SHA256 or SHA512"
  s.description  = %{Performs the UNIX crypt(3) algorithm using DES (standard 13 character passwords), MD5 (starting with $1$), SHA256 (starting with $5$) and SHA512 (starting with $6$)}
  s.files        = `git ls-files`.split($\)
  s.test_files   = s.files.grep(%r{^(test|spec|features)/})
  s.executables  = ["mkunixcrypt"]
  s.require_path = 'lib'
  s.has_rdoc     = false
  s.author       = "Roger Nesbitt"
  s.email        = "roger@seriousorange.com"
  s.homepage     = "https://github.com/mogest/unix-crypt"
  s.license      = "BSD"
end
