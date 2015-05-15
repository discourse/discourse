require_dependency 'scheduler/defer'

if defined? Unicorn::HttpServer
  ObjectSpace.each_object(Unicorn::HttpServer) do |s|
    s.extend(Scheduler::Defer::Unicorn)
  end

  if ENV['UNICORN_ENABLE_OOBGC'] == '1' && RUBY_VERSION < "2.2.0"
    require 'middleware/unicorn_oobgc'
    Middleware::UnicornOobgc.init
  end
end
