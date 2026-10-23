# frozen_string_literal: true

require "tmpdir"
require "timeout"

RSpec.describe TurboTests::DynamicFileAssignment do
  it "runs every example and context once, keeping each file on one worker" do
    Dir.mktmpdir("turbo-files") do |directory|
      files =
        %w[alpha beta gamma].map do |name|
          path = File.join(directory, "#{name}_spec.rb")
          File.write(path, <<~RUBY)
            2.times do |group|
              RSpec.describe "#{name} group \#{group}" do
                before(:context) { WorkerFixture.record(type: "setup", file: #{name.inspect}, group:) }
                after(:context) { WorkerFixture.record(type: "teardown", file: #{name.inspect}, group:) }

                3.times do |example|
                  it("example \#{example}") do
                    WorkerFixture.record(type: "example", file: #{name.inspect}, group:, example:)
                    sleep 0.01
                  end
                end
              end
            end
          RUBY
          path
        end

      result = run_workers(directory:, files:)

      expect(result[:statuses]).to all(eq(0)), result[:logs]
      expected =
        %w[alpha beta gamma]
          .product([0, 1], [0, 1, 2])
          .map { |name, group, example| "#{name} group #{group} example #{example}" }
      expect(
        result[:examples].map { |example| example.fetch("full_description") },
      ).to contain_exactly(*expected)

      %w[setup teardown].each do |type|
        contexts =
          result[:events]
            .select { |event| event.fetch("type") == type }
            .map { |event| [event.fetch("file"), event.fetch("group")] }
        expect(contexts).to contain_exactly(*%w[alpha beta gamma].product([0, 1]))
      end

      owners =
        result[:events]
          .group_by { |event| event.fetch("file") }
          .transform_values { |events| events.map { |event| event.fetch("worker") }.uniq }
      expect(owners.values.map(&:size)).to all(eq(1))
    end
  end

  it "lets available workers take more files while another worker stays busy" do
    Dir.mktmpdir("turbo-files") do |directory|
      slow = File.join(directory, "slow_spec.rb")
      File.write(slow, <<~'RUBY')
        RSpec.describe "slow file" do
          it "waits while other workers take more files" do
            WorkerFixture.record(type: "waiting", file: "slow", group: 0)
            directory = ENV.fetch("WORK_ASSIGNMENT_FIXTURE")
            File.write(File.join(directory, "slow-started"), "")
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
            until Dir.glob(File.join(directory, "finished-*")).size == 6
              raise "Available workers stopped taking files" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
              sleep 0.01
            end
            WorkerFixture.record(type: "released", file: "slow", group: 0)
          end
          2.times { |index| it("additional example #{index}") { expect(true).to eq(true) } }
        end
      RUBY
      fast =
        6.times.map do |index|
          path = File.join(directory, "fast_#{index}_spec.rb")
          File.write(path, <<~RUBY)
            RSpec.describe "fast file #{index}" do
              it "finishes" do
                directory = ENV.fetch("WORK_ASSIGNMENT_FIXTURE")
                deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
                until File.exist?(File.join(directory, "slow-started"))
                  raise "Slow worker did not start" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
                  sleep 0.01
                end
                WorkerFixture.record(type: "fast", file: #{index.to_s.inspect}, group: 0)
                File.write(File.join(ENV.fetch("WORK_ASSIGNMENT_FIXTURE"), "finished-#{index}"), "")
              end
            end
          RUBY
          path
        end

      result = run_workers(directory:, files: [slow, *fast])

      expect(result[:statuses]).to all(eq(0)), result[:logs]
      expect(result[:examples].size).to eq(9)
      waiting = result[:events].index { |event| event.fetch("type") == "waiting" }
      released = result[:events].index { |event| event.fetch("type") == "released" }
      completed = result[:events][(waiting + 1)...released]
      expect(completed.map { |event| event.fetch("type") }).to eq(Array.new(6, "fast"))
      busy_worker = result[:events][waiting].fetch("worker")
      expect(completed.map { |event| event.fetch("worker") }).not_to include(busy_worker)
      expect(completed.group_by { |event| event.fetch("worker") }.values.map(&:size).max).to be >= 3
    end
  end

  it "preserves filters, pending examples and failure diagnostics" do
    Dir.mktmpdir("turbo-files") do |directory|
      path = File.join(directory, "diagnostics_spec.rb")
      File.write(path, <<~RUBY)
        RSpec.describe "diagnostics" do
          it("passes", selected: true) { expect(1).to eq(1) }
          it("fails", selected: true) { raise "expected worker failure" }
          it("waits", selected: true) { skip "expected pending" }
          it("is filtered") { raise "must stay filtered" }
        end
      RUBY

      result = run_workers(directory:, files: [path], arguments: %w[--tag selected])

      expect(result[:statuses]).to contain_exactly(0, 0, 1), result[:logs]
      expect(
        result[:examples].map { |example| example.fetch("full_description") },
      ).to contain_exactly("diagnostics passes", "diagnostics fails", "diagnostics waits")
      failure = result[:examples].find { |example| example.fetch("status") == "failed" }
      expect(failure.fetch("exception").fetch("message")).to eq("expected worker failure")
      expect(failure.fetch("exception").fetch("backtrace").join("\n")).to include(path)
      pending = result[:examples].find { |example| example.fetch("status") == "pending" }
      expect(pending.fetch("pending_message")).to eq("expected pending")
      expect(result[:seeds]).to all(eq(42_167))
    end
  end

  it "can be loaded without enabling assignment or requiring RSpec" do
    source = Rails.root.join("lib/turbo_tests/dynamic_file_assignment.rb").to_s
    command = "require #{source.inspect}; abort unless defined?(TurboTests::DynamicFileAssignment)"

    _stdout, stderr, status =
      Open3.capture3({ "TURBO_RSPEC_FILE_CLAIMS" => nil }, Gem.ruby, "-e", command)

    expect(status.success?).to eq(true), stderr
  end

  private

  def run_workers(directory:, files:, arguments: [])
    claims = File.join(directory, "claims")
    FileUtils.mkdir_p(claims)
    options = File.join(directory, "empty.rspec")
    File.write(options, "")
    support = File.join(directory, "support.rb")
    File.write(support, <<~'RUBY')
      require "json"

      module WorkerFixture
        def self.record(type:, file:, group:, example: nil)
          event = { type:, file:, group:, example:, worker: ENV.fetch("TEST_ENV_NUMBER") }
          path = File.join(ENV.fetch("WORK_ASSIGNMENT_FIXTURE"), "events.jsonl")
          File.open(path, "a") do |output|
            output.flock(File::LOCK_EX)
            output.puts(JSON.generate(event))
          end
        end
      end

      RSpec.configure do |config|
        config.before(:suite) do
          directory = ENV.fetch("WORK_ASSIGNMENT_FIXTURE")
          File.write(File.join(directory, "ready-#{ENV.fetch('TEST_ENV_NUMBER')}"), "")
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
          until Dir.glob(File.join(directory, "ready-*")).size == 3
            raise "Workers did not become ready" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            sleep 0.01
          end
        end
      end
    RUBY

    processes = []
    3.times do |worker|
      environment = {
        "TURBO_RSPEC_FILE_CLAIMS" => claims,
        "TEST_ENV_NUMBER" => worker.to_s,
        "WORK_ASSIGNMENT_FIXTURE" => directory,
      }
      command = [
        Gem.ruby,
        Gem.bin_path("rspec-core", "rspec"),
        "--options",
        options,
        "--require",
        Rails.root.join("lib/turbo_tests/dynamic_file_assignment.rb").to_s,
        "--require",
        support,
        "--seed",
        "42167",
        "--format",
        "json",
        "--out",
        File.join(directory, "result-#{worker}.json"),
        *arguments,
        *files,
      ]
      processes << Process.spawn(
        environment,
        *command,
        out: File.join(directory, "output-#{worker}"),
        err: %i[child out],
      )
    end

    statuses =
      Timeout.timeout(45) { processes.map { |process| Process.wait2(process).last.exitstatus } }
    results =
      3.times.map { |worker| JSON.parse(File.read(File.join(directory, "result-#{worker}.json"))) }
    events = File.join(directory, "events.jsonl")
    {
      statuses:,
      examples: results.flat_map { |result| result.fetch("examples") },
      seeds: results.map { |result| result.fetch("seed") },
      events: File.exist?(events) ? File.readlines(events).map { |line| JSON.parse(line) } : [],
      logs: 3.times.map { |worker| File.read(File.join(directory, "output-#{worker}")) }.join("\n"),
    }
  ensure
    processes&.each do |process|
      if Process.waitpid(process, Process::WNOHANG).nil?
        Process.kill("TERM", process)
        Process.waitpid(process)
      end
    rescue Errno::ECHILD
    end
  end
end
