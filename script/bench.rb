require "socket"
require "csv"

def run(command)
  system(command, out: $stdout, err: :out)
end

puts "Running bundle"
if !run("bundle")
  puts "Quitting, some of the gems did not install"
  exit
end

puts "Ensuring config is setup"

unless %x{which ab > /dev/null 2>&1}
  abort "Apache Bench is not installed. Try: apt-get install apache2-utils or brew install ab"
end


unless File.exists?("config/database.yml")
  puts "Copying database.yml.development.sample to database.yml"
  `cp config/database.yml.development-sample config/database.yml`
end

unless File.exists?("config/redis.yml")
  puts "Copying redis.yml.sample to redis.yml"
  `cp config/redis.yml.sample config/redis.yml`
end

ENV["RAILS_ENV"] = "profile"

def port_available? port
  server = TCPServer.open port
  server.close
  true
rescue Errno::EADDRINUSE
  false
end

port = 60079

while !port_available? port
  port += 1
end

puts "Ensuring profiling DB exists and is migrated"
puts `bundle exec rake db:create`
`bundle exec rake db:migrate`

puts "Loading Rails"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")


begin
  unless pid = fork
    require "rack"
    Rack::Server.start(:config => "config.ru",
                       :AccessLog => [],
                       :Port => port)
    exit
  end

  while port_available? port
    sleep 1
  end

  puts "Running apache bench warmup"
  `ab -n 100 http://localhost:#{port}/`
  puts "Benchmarking front page"
  `ab -n 100 -e tmp/ab.csv http://localhost:#{port}/`

  percentiles = Hash[*[50, 75, 90, 99].zip([]).flatten]
  CSV.foreach("tmp/ab.csv") do |percent, time|
    percentiles[percent.to_i] = time.to_i if percentiles.key? percent.to_i
  end

  puts "Your Results:"

  puts({
    "home_page" => percentiles
  }.to_yaml)

ensure
  Process.kill "KILL", pid
end
