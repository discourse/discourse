require_dependency 'scheduler/defer'

if defined? Unicorn::HttpServer
  ObjectSpace.each_object(Unicorn::HttpServer) do |s|
    s.extend(Scheduler::Defer::Unicorn)
  end
end
