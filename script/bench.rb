require "socket"
require "csv"
require "yaml"

@timings = {}

def run(command)
  system(command, out: $stdout, err: :out)
end

def measure(name)
  start = Time.now
  yield
  @timings[name] = ((Time.now - start) * 1000).to_i
end

def prereqs
  puts "Be sure to following packages are installed:

sudo tasksel install postgresql-server
sudo apt-get -y install build-essential libssl-dev libyaml-dev git libtool libxslt-dev libxml2-dev libpq-dev gawk curl pngcrush python-software-properties

sudo apt-add-repository -y ppa:rwky/redis
sudo apt-get update
sudo apt-get install redis-server
  "
end

puts "Running bundle"
if !run("bundle")
  puts "Quitting, some of the gems did not install"
  prereqs
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

# Github settings
ENV["RAILS_ENV"] = "profile"
ENV["RUBY_GC_MALLOC_LIMIT"] = "1000000000"
ENV["RUBY_HEAP_SLOTS_GROWTH_FACTOR"] = "1.25"
ENV["RUBY_HEAP_MIN_SLOTS"] = "800000"
ENV["RUBY_FREE_MIN"] = "600000"


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
measure("load_rails") do
  `bundle exec rake middleware`
end


begin
  pid = spawn("bundle exec thin start -p #{port}")

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
    "home_page" => percentiles,
    "timings" => @timings
  }.to_yaml)

ensure
  Process.kill "KILL", pid
end
