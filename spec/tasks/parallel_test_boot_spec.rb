# frozen_string_literal: true
require "open3"
require "socket"
require "timeout"
require "tmpdir"
require_relative "../support/rspec_subprocess_environment"

RSpec.describe "Parallel test boot" do
  include RSpecSubprocessEnvironment

  it "waits for its own Redis process to exit" do
    Dir.mktmpdir("parallel-test-boot-") do |directory|
      listener = TCPServer.new("127.0.0.1", 0)
      port = listener.addr.fetch(1)
      listener.close
      number = port - 10_000
      ready = File.join(directory, "ready")
      environment =
        isolated_rspec_environment.merge(
          "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s,
          "RAILS_ENV" => "test",
          "TEST_ENV_NUMBER" => number.to_s,
          "DISABLE_BOOTSNAP" => "1",
        )
      program = <<~RUBY
        require ARGV.fetch(0)
        reader, writer = IO.pipe
        fork { reader.close; exit! }
        writer.close
        reader.read
        reader.close
        File.write(ARGV.fetch(1), "ready")
        STDIN.read(1)
      RUBY
      redis = Redis.new(host: "127.0.0.1", port: port, connect_timeout: 0.1, read_timeout: 0.1)
      redis_pid = nil

      Open3.popen3(
        environment,
        RbConfig.ruby,
        "-rbundler/setup",
        "-e",
        program,
        Rails.root.join("config/boot.rb").to_s,
        ready,
        chdir: directory,
        pgroup: true,
      ) do |input, output, error, waiter|
        begin
          Timeout.timeout(10) do
            until File.file?(ready)
              raise error.read unless waiter.alive?
              sleep 0.01
            end
            begin
              candidate_pid = Integer(redis.info("server").fetch("process_id"))
              expect(Process.getpgid(candidate_pid)).to eq(waiter.pid)
              expect(redis.config(:get, "dir").fetch("dir")).to eq(
                File.join(File.realpath(directory), "tmp/test_data_#{number}/redis"),
              )
              redis_pid = candidate_pid
            rescue Redis::BaseConnectionError
              sleep 0.01
              retry
            end
          end
          Process.kill("STOP", redis_pid)
          input.write("exit")
          input.flush

          expect(waiter.join(1)).to eq(nil)
        ensure
          begin
            Process.kill("CONT", redis_pid) if redis_pid
          rescue Errno::ESRCH
          end
          input.close unless input.closed?
          unless waiter.join(10)
            Process.kill("KILL", -waiter.pid)
            waiter.join
          end
          begin
            redis.call("SHUTDOWN", "NOSAVE") if redis_pid
          rescue Redis::BaseConnectionError
          ensure
            redis.close
          end
        end

        expect(waiter.value.success?).to eq(true), output.read + error.read
      end
    end
  end
end
