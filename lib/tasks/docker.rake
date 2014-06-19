
def run_or_fail(command)
  pid = Process.spawn(command)
  Process.wait(pid)
  $?.exitstatus == 0
end

desc 'Run all tests (JS and code in a standalone environment)'
task 'docker:test' do
  begin

    exit 1 unless run_or_fail("git remote update")

    checkout = "master"
    if hash = ENV['COMMIT_HASH']
       checkout = hash
    end
    exit 1 unless run_or_fail("git checkout #{checkout}")
    exit 1 unless run_or_fail("bundle")

    puts "Cleaning up old test tmp data in tmp/test_data"
    `rm -fr tmp/test_data && mkdir -p tmp/test_data/redis && mkdir tmp/test_data/pg`

    puts "Starting background redis"
    @redis_pid = Process.spawn('redis-server --dir tmp/test_data/redis')

    @postgres_bin = "/usr/lib/postgresql/9.3/bin/"
    `#{@postgres_bin}initdb -D tmp/test_data/pg`

    puts "Starting postgres"
    @pg_pid = Process.spawn("#{@postgres_bin}postmaster -D tmp/test_data/pg")


    ENV["RAILS_ENV"] = "test"

    @good = run_or_fail("bundle exec rake db:create db:migrate")
    @good &&= run_or_fail("bundle exec rspec")
    @good &&= run_or_fail("bundle exec rake qunit:test")

  ensure
    puts "Terminating"

    Process.kill("TERM", @redis_pid)
    Process.kill("TERM", @pg_pid)
    Process.wait @redis_pid
    Process.wait @pg_pid
  end

  if !@good
    exit 1
  end

end
