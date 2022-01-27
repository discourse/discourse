# frozen_string_literal: true

# I like guard, don't get me wrong, but it is just not working right
# architecturally it can not do what I want it to do, this is how I want
# it to behave

desc "Run all specs automatically as needed"
task "autospec" => :environment do
  require 'autospec/manager'

  debug = ARGV.any? { |a|  a == "d" || a == "debug" } || ENV["DEBUG"]
  force_polling = ARGV.any? { |a| a == "p" || a == "polling" }
  latency = ((ARGV.find { |a| a =~ /l=|latency=/ } || "").split("=")[1] || 3).to_i

  if force_polling
    puts "Polling has been forced (slower) - checking every #{latency} #{"second".pluralize(latency)}"
  else
    puts "If file watching is not working, you can force polling with: bundle exec rake autospec p l=3"
  end

  puts "@@@@@@@@@@@@ Running in debug mode" if debug

  Autospec::Manager.run(force_polling: force_polling, latency: latency, debug: debug)
end

desc "Regenerate swagger docs on API spec change"
task "autospec:swagger" => :environment do
  require 'listen'
  require 'open3'

  puts "Listening to changes in spec/requests/api to regenerate Swagger docs."
  listener = Listen.to("spec/requests/api") do |modified, added, removed|
    puts "API doc file changed."
    Open3.popen3("spec/regenerate_swagger_docs") do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        puts line
      end
    end
  end
  listener.start
  sleep
end
