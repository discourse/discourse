if ENV['UNICORN_ENABLE_OOBGC'] == '1'
  require 'middleware/unicorn_oobgc'
  Middleware::UnicornOobgc.init
end
