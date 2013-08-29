require "socket"
require "csv"
require "yaml"

def run(command)
  system(command, out: $stdout, err: :out)
end

begin
  require 'facter'
rescue LoadError
  run "gem install facter"
  puts "just installed the facter gem, please re-run script"
  exit
end

@timings = {}


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
  server = TCPServer.open("0.0.0.0", port)
  server.close
  true
rescue Errno::EADDRINUSE
  false
end

@port = 60079

while !port_available? @port
  @port += 1
end

puts "Ensuring profiling DB exists and is migrated"
puts `bundle exec rake db:create`
`bundle exec rake db:migrate`

puts "Timing loading Rails"
measure("load_rails") do
  `bundle exec rake middleware`
end

puts "Populating Profile DB"
run("bundle exec ruby script/profile_db_generator.rb")

def bench(path)
  puts "Running apache bench warmup"
  `ab -n 100 http://127.0.0.1:#{@port}#{path}`
  puts "Benchmarking #{path}"
  `ab -n 100 -e tmp/ab.csv http://127.0.0.1:#{@port}#{path}`

  percentiles = Hash[*[50, 75, 90, 99].zip([]).flatten]
  CSV.foreach("tmp/ab.csv") do |percent, time|
    percentiles[percent.to_i] = time.to_i if percentiles.key? percent.to_i
  end

  percentiles
end

begin
  # critical cause cache may be incompatible or something
  `rm -fr tmp/cache`
  pid = spawn("bundle exec thin start -p #{@port}")

  while port_available? @port
    sleep 1
  end

  puts "Starting benchmark..."

  home_page = bench("/")
  topic_page = bench("/t/oh-how-i-wish-i-could-shut-up-like-a-tunnel-for-so/69")

  puts "Your Results: (note for timings- percentile is first, duration is second in millisecs)"

  facts = Facter.to_hash

  facts.delete_if{|k,v|
    !["operatingsystem","architecture","kernelversion",
    "memorysize", "physicalprocessorcount", "processor0",
    "virtual"].include?(k)
  }

  puts({
    "home_page" => home_page,
    "topic_page" => topic_page,
    "timings" => @timings,
    "ruby-version" => "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}",
    "rails4?" => ENV["RAILS4"] == "1"
  }.merge(facts).to_yaml)

  # TODO include Facter.to_hash ... for all facts

ensure
  Process.kill "KILL", pid
end
