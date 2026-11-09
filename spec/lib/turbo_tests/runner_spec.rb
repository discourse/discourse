# frozen_string_literal: true
require "tmpdir"
require_relative "../../../lib/turbo_tests"
require_relative "../../support/rspec_subprocess_environment"

RSpec.describe TurboTests::Runner do
  include RSpecSubprocessEnvironment

  it "records the processes that actually ran each assigned role" do
    original_environment = ENV.to_h
    original_migration_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths.dup
    original_tty = RSpec.configuration.tty
    original_color = RSpec.configuration.color
    source = Dir.pwd
    Dir.mktmpdir("turbo-roles-") do |directory|
      FileUtils.mkdir_p("#{directory}/spec")
      File.write("#{directory}/bootstrap.rb", <<~RUBY)
        require "json"
        require #{"#{source}/lib/turbo_tests/json_example".inspect}
        require #{"#{source}/lib/turbo_tests/json_rows_formatter".inspect}
      RUBY
      File.write("#{directory}/.rspec", "--require #{directory}/bootstrap.rb\n")
      File.write(
        "#{directory}/spec/roles_spec.rb",
        'RSpec.describe("Roles") { it("ordinary") { File.write("pid-1", Process.pid.to_s) }; it("multisite", type: :multisite) { File.write("pid-multisite", Process.pid.to_s) } }',
      )
      isolated_rspec_environment
        .except("TEST_ENV_NUMBER")
        .each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      ENV["PARALLEL_TEST_PROCESSORS"] = "1"

      Dir.chdir(directory) do
        result =
          described_class.run(
            files: ["spec/roles_spec.rb"],
            formatters: [],
            execution_plan_path: "manifest.json",
            seed: 1234,
          )
        manifest = JSON.parse(File.read("manifest.json"))

        expect(result).to eq(true)
        expect(manifest.fetch("workers").keys.sort).to eq(%w[1 multisite])
        manifest
          .fetch("workers")
          .each do |role, assignment|
            expect(assignment).to eq(
              "files" => ["spec/roles_spec.rb"],
              "pid" => Integer(File.read("pid-#{role}")),
            )
          end
      end
    end
  ensure
    ENV.replace(original_environment)
    ActiveRecord::Tasks::DatabaseTasks.migrations_paths = original_migration_paths
    RSpec.configuration.tty = original_tty
    RSpec.configuration.color = original_color
  end

  it "records every collection batch and waits for its process before reusing a database slot" do
    original_environment = ENV.to_h
    original_migration_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths.dup
    original_tty = RSpec.configuration.tty
    original_color = RSpec.configuration.color
    source = Dir.pwd
    Dir.mktmpdir("turbo-batches-") do |directory|
      FileUtils.mkdir_p("#{directory}/spec")
      File.write("#{directory}/bootstrap.rb", <<~RUBY)
        require "json"
        require #{"#{source}/lib/turbo_tests/json_example".inspect}
        require #{"#{source}/lib/turbo_tests/json_rows_formatter".inspect}
        RSpec.configure do |config|
          config.before(:suite) do
            lease = "slot-\#{ENV.fetch('TEST_ENV_NUMBER', 'multisite')}"
            raise "Database slot reused before process exit" if File.exist?(lease)
            File.write(lease, Process.pid.to_s)
            at_exit do
              sleep 0.5
              File.delete(lease)
            end
          end
        end
      RUBY
      File.write("#{directory}/.rspec", "--require #{directory}/bootstrap.rb\n")
      files =
        81.times.map do |index|
          path = "spec/batch_#{index}_spec.rb"
          File.write("#{directory}/#{path}", <<~RUBY)
          RSpec.describe("Batch #{index}") do
            it("runs") do
              File.open("executed.jsonl", "a") do |output|
                output.puts(JSON.generate(file: #{path.inspect}, pid: Process.pid, slot: ENV.fetch("TEST_ENV_NUMBER"), identity: ENV.fetch("TEST_MAPPING_PROCESS_ID")))
              end
            end
          end
        RUBY
          path
        end
      isolated_rspec_environment.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      ENV.update(
        "PARALLEL_TEST_PROCESSORS" => "1",
        "COLLECT_TEST_MAPPING" => "1",
        "GITHUB_SHA" => "b" * 40,
      )

      Dir.chdir(directory) do
        result =
          described_class.run(
            files: files,
            formatters: [],
            execution_plan_path: "manifest.json",
            seed: 1234,
          )
        manifest = JSON.parse(File.read("manifest.json"))
        workers = manifest.fetch("workers")
        regular = workers.reject { |identity, _| identity == "multisite" }
        executed = File.readlines("executed.jsonl").map { |line| JSON.parse(line) }

        expect(result).to eq(true)
        expect(workers.fetch("multisite").fetch("files")).to match_array(files)
        expect(regular.length).to be > 1
        expect(regular.values.flat_map { |worker| worker.fetch("files") }).to match_array(files)
        expect(regular.values.map { |worker| worker.fetch("files").length }.max).to be <= 40
        expect(regular.values.map { |worker| worker.fetch("pid") }.uniq.length).to eq(
          regular.length,
        )
        expect(executed.map { |record| record.fetch("file") }).to match_array(files)
        expect(executed.map { |record| record.fetch("slot") }.uniq).to eq(["1"])
        executed.each do |record|
          assignment = workers.fetch(record.fetch("identity"))
          expect(assignment.fetch("pid")).to eq(record.fetch("pid"))
          expect(assignment.fetch("files")).to include(record.fetch("file"))
        end
        expect(Dir["slot-*"]).to eq([])
      end
    end
  ensure
    ENV.replace(original_environment)
    ActiveRecord::Tasks::DatabaseTasks.migrations_paths = original_migration_paths
    RSpec.configuration.tty = original_tty
    RSpec.configuration.color = original_color
  end

  it "rejects a grouping inventory that omits selected files" do
    expect do
      described_class.run(
        files: ["spec/selected_spec.rb"],
        grouping_files: ["spec/other_spec.rb"],
        formatters: [],
        seed: 1234,
      )
    end.to raise_error(ArgumentError, "Grouping inventory must contain every selected test file")
  end

  it "keeps selected files in their full inventory process group" do
    original_environment = ENV.to_h
    original_migration_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths.dup
    original_tty = RSpec.configuration.tty
    original_color = RSpec.configuration.color
    source = Dir.pwd
    Dir.mktmpdir("turbo-selection-") do |directory|
      FileUtils.mkdir_p("#{directory}/spec")
      File.write("#{directory}/bootstrap.rb", <<~RUBY)
        require "json"
        require #{"#{source}/lib/turbo_tests/json_example".inspect}
        require #{"#{source}/lib/turbo_tests/json_rows_formatter".inspect}
      RUBY
      File.write("#{directory}/.rspec", "--require #{directory}/bootstrap.rb\n")
      selected = %w[spec/first_spec.rb spec/second_spec.rb]
      selected.each { |path| File.write("#{directory}/#{path}", <<~RUBY) }
          RSpec.describe(#{path.inspect}) do
            it("records its process") do
              File.write(#{"#{path}.json".inspect}, JSON.generate(pid: Process.pid, slot: ENV.fetch("TEST_ENV_NUMBER")))
            end
          end
        RUBY
      unrelated = "spec/unrelated_spec.rb"
      File.write("#{directory}/#{unrelated}", <<~RUBY)
        RSpec.describe("Unrelated") do
          it("runs independently") { expect(#{"independent".ljust(2_000).inspect}).to start_with("independent") }
        end
      RUBY
      inventory = selected + [unrelated]
      isolated_rspec_environment.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      ENV["PARALLEL_TEST_PROCESSORS"] = "2"

      Dir.chdir(directory) do
        full = described_class.run(files: inventory, formatters: [], seed: 1234)
        full_processes = selected.map { |path| JSON.parse(File.read("#{path}.json")) }
        selected.each { |path| File.delete("#{path}.json") }

        subset =
          described_class.run(
            files: selected,
            grouping_files: inventory,
            formatters: [],
            seed: 1234,
            execution_plan_path: "selected-manifest.json",
          )
        selected_processes = selected.map { |path| JSON.parse(File.read("#{path}.json")) }
        manifest = JSON.parse(File.read("selected-manifest.json"))

        expect(full).to eq(true)
        expect(subset).to eq(true)
        expect(full_processes.map { |process| process.fetch("pid") }.uniq.length).to eq(1)
        expect(selected_processes.map { |process| process.fetch("pid") }.uniq.length).to eq(1)
        expect(selected_processes.map { |process| process.fetch("slot") }).to eq(
          full_processes.map { |process| process.fetch("slot") },
        )
        expect(
          manifest.fetch("workers").values.flat_map { |worker| worker.fetch("files") }.uniq,
        ).to match_array(selected)
      end
    end
  ensure
    ENV.replace(original_environment)
    ActiveRecord::Tasks::DatabaseTasks.migrations_paths = original_migration_paths
    RSpec.configuration.tty = original_tty
    RSpec.configuration.color = original_color
  end

  it "rejects failed startup and malformed output without waiting for an unopened pipe" do
    source = Dir.pwd
    {
      "startup" => "raise 'Deliberate bootstrap failure'",
      "malformed" => <<~RUBY,
        require 'rspec/core/formatters/base_text_formatter'
        module TurboTests
          class JsonRowsFormatter < RSpec::Core::Formatters::BaseTextFormatter
            RSpec::Core::Formatters.register self, :start
            def start(_notification)
              output.puts('malformed test output')
              output.flush
            end
          end
        end
      RUBY
    }.each do |variant, bootstrap|
      Dir.mktmpdir("turbo-output-") do |directory|
        FileUtils.mkdir_p("#{directory}/spec")
        File.write("#{directory}/bootstrap.rb", bootstrap)
        File.write("#{directory}/.rspec", "--require #{directory}/bootstrap.rb\n")
        File.write(
          "#{directory}/spec/selected_spec.rb",
          'RSpec.describe("Selected") { it("runs") {} }',
        )
        File.write("#{directory}/run.rb", <<~RUBY)
          ENV["RAILS_ENV"] = "test"
          require #{"#{source}/lib/turbo_tests".inspect}
          Dir.chdir(#{directory.inspect}) do
            result = TurboTests::Runner.run(files: ["spec/selected_spec.rb"], formatters: [{name: "documentation", outputs: ["-"]}], seed: 1234, execution_plan_path: "manifest.json")
            File.write("result.json", JSON.generate("success" => result))
            exit(result ? 1 : 0)
          end
        RUBY
        environment =
          isolated_rspec_environment.merge(
            "COLLECT_TEST_MAPPING" => "1",
            "PARALLEL_TEST_PROCESSORS" => "1",
            "GITHUB_SHA" => "b" * 40,
            "LOAD_PLUGINS" => "0",
          )

        output, error, status =
          Open3.capture3(
            environment,
            "timeout",
            "--kill-after=2s",
            "30",
            RbConfig.ruby,
            "#{directory}/run.rb",
          )

        expect(status.success?).to eq(true), output + error
        expect(JSON.parse(File.read("#{directory}/result.json"))).to eq("success" => false)
        if variant == "malformed"
          expect(output).to include("Could not read test output from process")
        end
        expect(Discourse.redis.without_namespace.save).to eq("OK")
      end
    end
  end
end
