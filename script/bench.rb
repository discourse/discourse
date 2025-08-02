# frozen_string_literal: true

require "socket"
require "csv"
require "yaml"
require "optparse"
require "fileutils"
require "net/http"
require "uri"

@include_env = false
@result_file = nil
@iterations = 500
@best_of = 1
@mem_stats = false
@unicorn = false
@dump_heap = false
@concurrency = 1
@skip_asset_bundle = false
@unicorn_workers = 3

opts =
  OptionParser.new do |o|
    o.banner = "Usage: ruby bench.rb [options]"

    o.on("-n", "--with_default_env", "Include recommended Discourse env") { @include_env = true }
    o.on("-o", "--output [FILE]", "Output results to this file") { |f| @result_file = f }
    o.on("-i", "--iterations [ITERATIONS]", "Number of iterations to run the bench for") do |i|
      @iterations = i.to_i
    end
    o.on("-b", "--best_of [NUM]", "Number of times to run the bench taking best as result") do |i|
      @best_of = i.to_i
    end
    o.on("-d", "--heap_dump") do
      @dump_heap = true
      # We need an env var for config/boot.rb to enable allocation tracing prior to framework init
      ENV["DISCOURSE_DUMP_HEAP"] = "1"
    end
    o.on("-m", "--memory_stats") { @mem_stats = true }
    o.on(
      "-c",
      "--concurrency [NUM]",
      "Run benchmark with this number of concurrent requests (default: 1)",
    ) { |i| @concurrency = i.to_i }
    o.on(
      "-w",
      "--unicorn_workers [NUM]",
      "Run benchmark with this number of unicorn workers (default: 3)",
    ) { |i| @unicorn_workers = i.to_i }
    o.on("-s", "--skip-bundle-assets", "Skip bundling assets") { @skip_asset_bundle = true }

    o.on(
      "-t",
      "--tests [STRING]",
      "List of tests to run. Example: '--tests topic,categories')",
    ) { |i| @tests = i.split(",") }
  end
opts.parse!

def run(command, opt = nil)
  exit_status =
    if opt == :quiet
      system(command, out: "/dev/null", err: :out)
    else
      system(command, out: $stdout, err: :out)
    end

  abort("Command '#{command}' failed with exit status #{$?}") unless exit_status
end

begin
  require "facter"
  raise LoadError if Gem::Version.new(Facter.version) < Gem::Version.new("4.0")
rescue LoadError
  run "gem install facter"
  puts "please rerun script"
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

sudo apt-get -y install build-essential libssl-dev libyaml-dev git libtool libxslt-dev libxml2-dev libpq-dev gawk curl pngcrush python-software-properties software-properties-common tasksel

sudo tasksel install postgresql-server
OR
apt-get install postgresql-server^

sudo apt-add-repository -y ppa:rwky/redis
sudo apt-get update
sudo apt-get install redis-server
  "
end

puts "Running bundle"
if run("bundle", :quiet)
  puts "Quitting, some of the gems did not install"
  prereqs
  exit
end

puts "Ensuring config is setup"

`which ab > /dev/null 2>&1`
unless $? == 0
  abort "Apache Bench is not installed. Try: apt-get install apache2-utils or brew install ab"
end

unless File.exist?("config/database.yml")
  puts "Copying database.yml.development.sample to database.yml"
  `cp config/database.yml.development-sample config/database.yml`
end

ENV["RAILS_ENV"] = "profile"

discourse_env_vars = %w[
  DISCOURSE_DUMP_HEAP
  RUBY_GC_HEAP_INIT_SLOTS
  RUBY_GC_HEAP_FREE_SLOTS
  RUBY_GC_HEAP_GROWTH_FACTOR
  RUBY_GC_HEAP_GROWTH_MAX_SLOTS
  RUBY_GC_MALLOC_LIMIT
  RUBY_GC_OLDMALLOC_LIMIT
  RUBY_GC_MALLOC_LIMIT_MAX
  RUBY_GC_OLDMALLOC_LIMIT_MAX
  RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR
  RUBY_GC_OLDMALLOC_LIMIT_GROWTH_FACTOR
  RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR
  LD_PRELOAD
]

if @include_env
  puts "Running with tuned environment"
  discourse_env_vars.each { |v| ENV.delete v }

  ENV["RUBY_GC_HEAP_GROWTH_MAX_SLOTS"] = "40000"
  ENV["RUBY_GC_HEAP_INIT_SLOTS"] = "400000"
  ENV["RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR"] = "1.5"
else
  # clean env
  puts "Running with the following custom environment"
end

discourse_env_vars.each { |w| puts "#{w}: #{ENV[w]}" if ENV[w].to_s.length > 0 }

def port_available?(port)
  server = TCPServer.open("0.0.0.0", port)
  server.close
  true
rescue Errno::EADDRINUSE
  false
end

@port = 60_079

@port += 1 while !port_available? @port

puts "Ensuring profiling DB exists and is migrated"
puts `bundle exec rake db:create`
`bundle exec rake db:migrate`

puts "Timing loading Rails"
measure("load_rails") { `bundle exec rails middleware` }

puts "Populating Profile DB"
run("bundle exec ruby script/profile_db_generator.rb")

puts "Getting admin api key"
admin_api_key = `bundle exec rake api_key:create_master[bench]`.split("\n")[-1]
raise "Failed to obtain a user API key" if admin_api_key.to_s.empty?

puts "Getting user api key"
user_api_key = `bundle exec rake user_api_key:create[user1]`.split("\n")[-1]
raise "Failed to obtain a user API key" if user_api_key.to_s.empty?

def bench(path, name, headers)
  puts "Running apache bench warmup"
  add = ""
  add = "-c #{@concurrency} " if @concurrency > 1
  header_string = headers&.map { |k, v| "-H \"#{k}:#{v}\"" }&.join(" ")
  `ab #{add} #{header_string} -n 20 -l "http://127.0.0.1:#{@port}#{path}"`

  puts "Benchmarking #{name} @ #{path}"
  `ab #{add} #{header_string} -n #{@iterations} -l -e tmp/ab.csv "http://127.0.0.1:#{@port}#{path}"`

  percentiles = Hash[*[50, 75, 90, 99].zip([]).flatten]
  CSV.foreach("tmp/ab.csv") do |percent, time|
    percentiles[percent.to_i] = time.to_i if percentiles.key? percent.to_i
  end

  percentiles
end

begin
  # critical cause cache may be incompatible
  unless @skip_asset_bundle
    puts "precompiling assets"
    run("bundle exec rake assets:precompile")
  end

  ENV["UNICORN_PORT"] = @port.to_s
  ENV["UNICORN_WORKERS"] = @unicorn_workers.to_s

  FileUtils.mkdir_p(File.join("tmp", "pids"))
  pid = spawn("bundle exec unicorn -c config/unicorn.conf.rb")

  while (
          unicorn_master_pid =
            `ps aux | grep "unicorn master" | grep -v "grep" | awk '{print $2}'`.strip.to_i
        ) == 0
    sleep 1
  end

  while `pgrep -P #{unicorn_master_pid}`.split("\n").map(&:to_i).size != @unicorn_workers.to_i
    sleep 1
  end

  puts "Starting benchmark..."

  admin_headers = { "Api-Key" => admin_api_key, "Api-Username" => "admin1" }

  user_headers = { "User-Api-Key" => user_api_key }

  # asset precompilation is a dog, wget to force it
  run "curl -s -o /dev/null http://127.0.0.1:#{@port}/"

  redirect_response = `curl -s -I "http://127.0.0.1:#{@port}/t/i-am-a-topic-used-for-perf-tests"`
  raise "Unable to locate topic for perf tests" if redirect_response !~ /301 Moved Permanently/

  topic_url =
    redirect_response.match(%r{^location: .+(/t/i-am-a-topic-used-for-perf-tests/.+)$}i)[1].strip

  all_tests = [
    %w[categories /categories],
    %w[home /],
    ["topic", topic_url],
    ["topic.json", "#{topic_url}.json"],
    ["user activity", "/u/admin1/activity"],
  ]

  @tests ||= %w[categories home topic]

  tests_to_run = all_tests.select { |test_name, path| @tests.include?(test_name) }

  tests_to_run.concat(
    tests_to_run.map { |k, url| ["#{k} user", "#{url}", user_headers] },
    tests_to_run.map { |k, url| ["#{k} admin", "#{url}", admin_headers] },
  )

  tests_to_run.each do |test_name, path, headers_for_path|
    uri = URI.parse("http://127.0.0.1:#{@port}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)

    headers_for_path&.each { |key, value| request[key] = value }

    response = http.request(request)

    raise "#{test_name} #{path} returned non 200 response code" if response.code != "200"
  end

  # NOTE: we run the most expensive page first in the bench

  def best_of(a, b)
    return a unless b
    return b unless a

    a[50] < b[50] ? a : b
  end

  results = {}
  @best_of.times do
    tests_to_run.each do |name, url, headers|
      results[name] = best_of(bench(url, name, headers), results[name])
    end
  end

  puts "Your Results: (note for timings- percentile is first, duration is second in millisecs)"

  puts "Unicorn: (workers: #{@unicorn_workers})"
  puts "Include env: #{@include_env}"
  puts "Iterations: #{@iterations}, Best of: #{@best_of}"
  puts "Concurrency: #{@concurrency}"
  puts

  # Prevent using external facts because it breaks when running in the
  # discourse/discourse_bench docker container.
  Facter.reset
  facts = Facter.to_hash

  facts.delete_if do |k, v|
    !%w[
      operatingsystem
      architecture
      kernelversion
      memorysize
      physicalprocessorcount
      processor0
      virtual
    ].include?(k)
  end

  run("RAILS_ENV=profile bundle exec rake assets:clean")

  def get_mem(pid)
    YAML.safe_load `ruby script/memstats.rb #{pid} --yaml`
  end

  mem = get_mem(pid)

  results =
    results.merge(
      "timings" => @timings,
      "ruby-version" => "#{RUBY_DESCRIPTION}",
      "yjit" => RubyVM::YJIT.enabled?,
      "rss_kb" => mem["rss_kb"],
      "pss_kb" => mem["pss_kb"],
    ).merge(facts)

  if @unicorn
    child_pids = `ps --ppid #{pid} | awk '{ print $1; }' | grep -v PID`.split("\n")
    child_pids.each do |child|
      mem = get_mem(child)
      results["rss_kb_#{child}"] = mem["rss_kb"]
      results["pss_kb_#{child}"] = mem["pss_kb"]
    end
  end

  puts results.to_yaml

  if @mem_stats
    puts
    puts open("http://127.0.0.1:#{@port}/admin/memory_stats", headers).read
  end

  if @dump_heap
    puts
    puts open("http://127.0.0.1:#{@port}/admin/dump_heap", headers).read
  end

  File.open(@result_file, "wb") { |f| f.write(results) } if @result_file
ensure
  Process.kill "KILL", pid
end
