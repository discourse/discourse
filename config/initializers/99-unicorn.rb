if ENV['UNICORN_ENABLE_OOBGC']
  require 'middleware/unicorn_oobgc'
  Middleware::UnicornOobgc.init
end
