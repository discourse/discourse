# frozen_string_literal: true

require "tmpdir"
require "timeout"

RSpec.describe TurboTests do
  it "runs every selected example once, keeping each regular file on one worker" do
    Dir.mktmpdir("turbo-files") do |directory|
      files =
        %w[system request multisite].map do |type|
          path = File.join(directory, "#{type}_spec.rb")
          File.write(path, <<~RUBY)
            2.times do |group|
              RSpec.describe "#{type} group \#{group}", type: :#{type} do
                2.times { |example| it("example \#{example}") { expect(true).to eq(true) } }
              end
            end
          RUBY
          path
        end

      mixed = File.join(directory, "mixed_spec.rb")
      File.write(mixed, <<~'RUBY')
        RSpec.describe "mixed file", type: :system do
          it("regular example") { expect(true).to eq(true) }
          context "nested multisite", type: :multisite do
            it("multisite example") { expect(true).to eq(true) }
            context "inherited type" do
              it("deeper multisite example") { expect(true).to eq(true) }
            end
          end
          it("excluded example", if: false) { raise "excluded example ran" }
        end
      RUBY

      regular = run_workers(directory:, files: [*files, mixed], workers: [1, 2, 3])
      multisite = run_workers(directory:, files: [*files, mixed], workers: [nil])
      expected =
        files.product([1, 2], [1, 2]).map { |file, group, example| "#{file}[#{group}:#{example}]" }
      regular_ids =
        regular
          .flat_map { |result| result.fetch("examples") }
          .map { |example| File.expand_path(example.fetch("id")) }
      multisite_ids =
        multisite.sole.fetch("examples").map { |example| File.expand_path(example.fetch("id")) }

      expect(regular_ids).to contain_exactly(
        *expected.reject { |id| id.start_with?(files.last) },
        "#{mixed}[1:1]",
      )
      expect(multisite_ids).to contain_exactly(
        *expected.select { |id| id.start_with?(files.last) },
        "#{mixed}[1:2:1]",
        "#{mixed}[1:2:2:1]",
      )
      regular_owners =
        regular.each_with_index.flat_map do |result, worker|
          result.fetch("examples").map { |example| [example.fetch("file_path"), worker] }
        end
      expect(
        regular_owners.group_by(&:first).values.map { |owners| owners.map(&:last).uniq.size },
      ).to eq([1, 1, 1])
    end
  end

  it "lets other workers finish more files while one worker is held" do
    Dir.mktmpdir("turbo-files") do |directory|
      slow = File.join(directory, "slow_spec.rb")
      File.write(slow, <<~'RUBY')
        RSpec.describe "slow file" do
          it "waits for the other files" do
            directory = ENV.fetch("TURBO_FILE_SPEC_DIRECTORY")
            File.write(File.join(directory, "slow-started"), "")
            Timeout.timeout(10) do
              sleep 0.01 until Dir.glob(File.join(directory, "finished-*")).size == 6
            end
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
                directory = ENV.fetch("TURBO_FILE_SPEC_DIRECTORY")
                Timeout.timeout(10) do
                  sleep 0.01 until File.exist?(File.join(directory, "slow-started"))
                end
                File.write(File.join(directory, "finished-#{index}"), "")
              end
            end
          RUBY
          path
        end

      results = run_workers(directory:, files: [slow, *fast], workers: [1, 2, 3])
      expected =
        (1..3).map { |example| "#{slow}[1:#{example}]" } + fast.map { |file| "#{file}[1:1]" }
      expect(
        results
          .flat_map { |result| result.fetch("examples") }
          .map { |example| File.expand_path(example.fetch("id")) },
      ).to contain_exactly(*expected)
    end
  end

  private

  def run_workers(directory:, files:, workers:)
    claims = File.join(directory, "claims")
    FileUtils.mkdir_p(claims)
    support = File.join(directory, "barrier.rb")
    File.write(support, <<~'RUBY')
      require "timeout"

      RSpec.configure do |config|
        config.before(:suite) do
          next unless ENV["TEST_ENV_NUMBER"]
          directory = ENV.fetch("TURBO_FILE_SPEC_DIRECTORY")
          File.write(File.join(directory, "ready-#{ENV.fetch('TEST_ENV_NUMBER')}"), "")
          Timeout.timeout(10) do
            sleep 0.01 until Dir.glob(File.join(directory, "ready-*")).size == 3
          end
        end
      end
    RUBY

    processes = []
    workers.each do |worker|
      environment = {
        "TEST_ENV_NUMBER" => worker&.to_s,
        "TURBO_RSPEC_FILE_CLAIMS" => worker ? claims : nil,
        "TURBO_FILE_SPEC_DIRECTORY" => directory,
        "SPEC_OPTS" => nil,
      }
      command = [
        Gem.ruby,
        Gem.bin_path("rspec-core", "rspec"),
        "--options",
        "/dev/null",
        "--require",
        Rails.root.join("lib/turbo_tests/dynamic_file_assignment.rb").to_s,
        "--require",
        support,
        "--seed",
        "42167",
        "--format",
        "json",
        "--out",
        File.join(directory, "result-#{worker || "multisite"}.json"),
        *files,
      ]
      processes << Process.spawn(
        environment,
        *command,
        out: File.join(directory, "output-#{worker || "multisite"}"),
        err: %i[child out],
      )
    end

    statuses =
      Timeout.timeout(30) { processes.map { |process| Process.wait2(process).last.exitstatus } }
    logs =
      workers
        .map { |worker| File.read(File.join(directory, "output-#{worker || "multisite"}")) }
        .join("\n")
    expect(statuses).to all(eq(0)), logs
    workers.map do |worker|
      result = JSON.parse(File.read(File.join(directory, "result-#{worker || "multisite"}.json")))
      expect(result.fetch("examples").map { |example| example.fetch("status") }).to all(
        eq("passed"),
      ),
      logs
      result
    end
  ensure
    processes&.each do |process|
      if Process.waitpid(process, Process::WNOHANG).nil?
        Process.kill("KILL", process)
        Process.waitpid(process)
      end
    rescue Errno::ECHILD
    end
  end
end
