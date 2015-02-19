require_dependency 'scheduler/defer'

if defined? Unicorn::HttpServer
  ObjectSpace.each_object(Unicorn::HttpServer) do |s|
    s.extend(Scheduler::Defer::Unicorn)
  end

  if ENV['UNICORN_ENABLE_OOBGC'] == '1'
    require 'middleware/unicorn_oobgc'
    Middleware::UnicornOobgc.init
  end
end
