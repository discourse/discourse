# frozen_string_literal: true

require "json"
require "open3"
require "tmpdir"
require_relative "../support/rspec_subprocess_environment"

RSpec.describe "CI support" do
  include RSpecSubprocessEnvironment

  it "finishes an example when its backtrace logger starts waiting late" do
    source = Dir.pwd
    Dir.mktmpdir("ci-logger-") do |directory|
      fixture = File.join(directory, "example_spec.rb")
      report = File.join(directory, "result.json")
      File.write(fixture, <<~RUBY)
        RSpec.describe("CI logger handshake") do
          it("finishes its body") { LOGGER_PAUSED.pop(timeout: 0.25) }
        end
      RUBY
      program = <<~RUBY
        require "rspec/core"
        require "timeout"
        LOGGER_PAUSED = Queue.new
        release = Queue.new
        main = Thread.current
        logger = nil
        paused = false
        released = false
        support = #{File.join(source, "spec/support/ci.rb").inspect}
        point = TracePoint.new(:c_call, :c_return) do |event|
          if event.event == :c_call && event.method_id == :sleep &&
               event.path == support && Thread.current != main && !paused
            paused = true
            logger = Thread.current
            LOGGER_PAUSED << true
            release.pop
          elsif event.event == :c_return && event.method_id == :wakeup &&
                  Thread.current == main && event.self.equal?(logger) && !released
            released = true
            release << true
          end
        end
        point.enable
        load support
        status = RSpec::Core::Runner.run([
          "--options", "/dev/null", ARGV.fetch(0),
          "--format", "json", "--out", ARGV.fetch(1),
        ])
        point.disable
        exit status
      RUBY
      environment =
        isolated_rspec_environment.merge(
          "CI" => "1",
          "GITHUB_ACTIONS" => nil,
          "COLLECT_TEST_MAPPING" => "1",
          "COLLECT_RSPEC_MAPPING" => "0",
          "DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE" => nil,
          "RUBYOPT" => nil,
        )
      status = nil
      output = nil
      errors = nil
      Open3.popen3(
        environment,
        RbConfig.ruby,
        "-rbundler/setup",
        "-e",
        program,
        fixture,
        report,
        pgroup: true,
      ) do |input, stdout, stderr, process|
        input.close
        begin
          status = process.join(5)&.value
        ensure
          unless status
            begin
              Process.kill("KILL", -process.pid)
            rescue Errno::ESRCH
              status = process.value
            end
            process.value
          end
          output = stdout.read
          errors = stderr.read
        end
      end

      expect(status&.success?).to eq(true), "Child RSpec did not finish: #{output}\n#{errors}"
      expect(JSON.parse(File.read(report)).fetch("summary")).to include(
        "example_count" => 1,
        "failure_count" => 0,
        "errors_outside_of_examples_count" => 0,
      )
    end
  end

  it "preserves clock values stubbed by examples" do
    source = Dir.pwd
    Dir.mktmpdir("ci-clock-") do |directory|
      fixture = File.join(directory, "example_spec.rb")
      report = File.join(directory, "result.json")
      File.write(fixture, <<~RUBY)
        require "mocha/api"
        RSpec.configure { |configuration| configuration.mock_with :mocha }
        load #{File.join(source, "spec/support/ci.rb").inspect}
        RSpec.describe("CI clock isolation") do
          20.times do
            it("preserves the example clock sequence") do
              Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 0.06, 0.06, 0.12)
              IO.select(nil, nil, nil, 0.02)
              values = 2.times.map { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
              expect(values).to eq([0.0, 0.06])
            end
          end
        end
      RUBY
      program = <<~RUBY
        require "timeout"
        require "rspec/core"
        exit RSpec::Core::Runner.run(ARGV)
      RUBY
      environment =
        isolated_rspec_environment.merge(
          "CI" => "1",
          "GITHUB_ACTIONS" => nil,
          "COLLECT_TEST_MAPPING" => "1",
          "COLLECT_RSPEC_MAPPING" => "0",
          "DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE" => nil,
          "RUBYOPT" => nil,
        )
      status = nil
      output = nil
      errors = nil
      Open3.popen3(
        environment,
        RbConfig.ruby,
        "-rbundler/setup",
        "-e",
        program,
        "--",
        "--options",
        "/dev/null",
        fixture,
        "--format",
        "json",
        "--out",
        report,
        pgroup: true,
      ) do |input, stdout, stderr, process|
        input.close
        begin
          status = process.join(5)&.value
        ensure
          unless status
            begin
              Process.kill("KILL", -process.pid)
            rescue Errno::ESRCH
              status = process.value
            end
            process.value
          end
          output = stdout.read
          errors = stderr.read
        end
      end

      expect(File.exist?(report)).to eq(true), "Child RSpec did not report: #{output}\n#{errors}"
      expect(JSON.parse(File.read(report)).fetch("summary")).to include(
        "example_count" => 20,
        "failure_count" => 0,
        "errors_outside_of_examples_count" => 0,
      )
      expect(status&.success?).to eq(true), "Child RSpec failed: #{output}\n#{errors}"
    end
  end
end
