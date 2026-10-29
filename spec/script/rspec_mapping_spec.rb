# frozen_string_literal: true

require "rails_helper"
require "crystalball"
require "open3"
require "tmpdir"
require_relative "../../script/ci/rspec_source_structure"

RSpec.describe Crystalball do
  it "records outer setup and nested shared examples against the including spec" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/spec/support")
      FileUtils.mkdir_p("#{directory}/lib")
      File.write("#{directory}/lib/boot.txt", "42")
      File.write("#{directory}/lib/data.txt", "42")
      File.symlink("data.txt", "#{directory}/lib/data-link.txt")
      File.write(
        "#{directory}/lib/definition.rb",
        "class Definition\n  VALUE = 42\n  BOOT = File.read(File.expand_path(\"boot.txt\", __dir__))\nend\n",
      )
      File.write("#{directory}/lib/setup.rb", <<~RUBY)
        module Setup
          def self.value
            42.to_s
          end
        end
      RUBY
      File.write("#{directory}/lib/body.rb", <<~RUBY)
        module Body
          def self.value
            File.open(Pathname.new(File.expand_path("data-link.txt", __dir__)), &:read)
          end
        end
      RUBY
      File.write("#{directory}/spec/support/shared.rb", <<~RUBY)
        RSpec.shared_examples "a value" do
          it("computes a value") { expect(Body.value).to eq("42") }
        end
      RUBY
      File.write("#{directory}/spec/example_spec.rb", <<~RUBY)
        require_relative "../lib/setup"
        require_relative "../lib/body"
        require_relative "../lib/definition"
        require_relative "support/shared"
        RSpec.describe Definition do
          before(:context) { Setup.value }
          context "nested" do
            it_behaves_like "a value"
          end
        end
      RUBY

      File.write("#{directory}/spec/skipped_spec.rb", <<~RUBY)
        RSpec.describe "skipped", skip: true do
          it("waits") { expect(1).to eq(1) }
        end
        RSpec.configure do |config|
          config.prepend_after(:suite) do
            RSpec.describe "a group registered after execution" do
              it("was not scheduled") { expect(false).to eq(true) }
            end
          end
        end
      RUBY

      output, status =
        Open3.capture2e(
          {
            "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s,
            "GITHUB_SHA" => "a" * 40,
            "RSPEC_MAPPING_DIRECTORY" => "#{directory}/mapping",
          },
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--require",
          Rails.root.join("script/ci/rspec_mapping.rb").to_s,
          "spec/example_spec.rb",
          "spec/skipped_spec.rb",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      worker = JSON.parse(File.read(Dir["#{directory}/mapping/worker-*.json"].sole))
      expect(worker["complete"]).to eq(true)
      expect(worker["dependencies"].keys).to eq(["spec/example_spec.rb"])
      expect(worker["shared_files"]).to include("lib/boot.txt", "lib/data.txt", "lib/data-link.txt")
      expect(worker["shared_files"]).not_to include(
        "lib/setup.rb",
        "lib/body.rb",
        "lib/definition.rb",
      )
      expect(worker["dependencies"]["spec/example_spec.rb"]).to include(
        "lib/setup.rb",
        "lib/body.rb",
        "lib/definition.rb",
        "spec/support/shared.rb",
      )
    end
  end

  it "passes a selection plan to the runner and skips an empty selection" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/tmp/rspec-mapping")
      FileUtils.mkdir_p("#{directory}/spec/views")
      FileUtils.mkdir_p("#{directory}/bin")
      File.write("#{directory}/spec/views/example.html.erb_spec.rb", "")
      File.write("#{directory}/bin/turbo_rspec", <<~RUBY)
        #!/usr/bin/env ruby
        require "json"
        File.write("arguments.json", JSON.generate(ARGV))
        File.write("tmp/rspec-mapping/execution.json", JSON.generate(revision: ENV["GITHUB_SHA"], workers: { "1" => ["spec/views/example.html.erb_spec.rb"] }, predicted_regular_specs: ["spec/views/example.html.erb_spec.rb"], predicted_multisite_specs: []))
      RUBY
      FileUtils.chmod("+x", "#{directory}/bin/turbo_rspec")
      selection_path = "#{directory}/tmp/rspec-mapping/selection.json"
      revision = "b" * 40
      selection = {
        source_checks: {
        },
        mode: "subset",
        revision: revision,
        specs: ["spec/views/example.html.erb_spec.rb"],
        cohort_specs: [],
        full_multisite: false,
      }
      File.write(selection_path, JSON.generate(selection))

      output, status =
        Open3.capture2e(
          {
            "GITHUB_SHA" => revision,
            "COLLECT_RSPEC_MAPPING" => nil,
            "RSPEC_SELECTION_AUDIT" => nil,
            "RUBYOPT" => nil,
          },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "run",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      expect(JSON.parse(File.read("#{directory}/arguments.json"))).to eq(
        %w[
          --use-runtime-info
          --format=progress
          --execution-plan
          tmp/rspec-mapping/execution.json
          --selection
          tmp/rspec-mapping/selection.json
        ],
      )

      File.delete("#{directory}/arguments.json")
      File.write(selection_path, JSON.generate(selection.merge(specs: [], cohort_specs: [])))

      output, status =
        Open3.capture2e(
          {
            "GITHUB_SHA" => revision,
            "COLLECT_RSPEC_MAPPING" => nil,
            "RSPEC_SELECTION_AUDIT" => nil,
            "RUBYOPT" => nil,
          },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "run",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      expect(File.exist?("#{directory}/arguments.json")).to eq(false)
    end
  end

  it "records an omitted failure raised by shared context setup" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/tmp/rspec-mapping")
      FileUtils.mkdir_p("#{directory}/spec")
      File.write(
        "#{directory}/tmp/rspec-mapping/execution.json",
        JSON.generate(predicted_regular_specs: [], predicted_multisite_specs: []),
      )
      File.write("#{directory}/spec/example_spec.rb", <<~RUBY)
        RSpec.describe "shared setup failure" do
          before(:context) { raise "regression" }
          it("uses the setup") { expect(true).to eq(true) }
        end
      RUBY
      output, status =
        Open3.capture2e(
          { "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s },
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--require",
          Rails.root.join("script/ci/rspec_selection_audit.rb").to_s,
          "spec/example_spec.rb",
          chdir: directory,
        )
      expect(status.success?).to eq(false), output
      report = JSON.parse(File.read(Dir["#{directory}/tmp/rspec-mapping/audit-worker-*.json"].sole))
      expect(report["complete"]).to eq(true)
      expect(report["omitted_failures"]).to eq(["./spec/example_spec.rb[1:1]"])
      expect(report["failures"]).to eq(report["omitted_failures"])
    end
  end

  it "attributes shared example audit failures to their including spec" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/tmp/rspec-mapping")
      FileUtils.mkdir_p("#{directory}/spec/support")
      File.write(
        "#{directory}/tmp/rspec-mapping/execution.json",
        JSON.generate(
          predicted_regular_specs: ["spec/example_spec.rb"],
          predicted_multisite_specs: ["spec/example_spec.rb"],
        ),
      )
      File.write("#{directory}/spec/support/shared.rb", <<~RUBY)
        RSpec.shared_examples "a regression" do
          it("detects a regression") { expect(false).to eq(true) }
        end
      RUBY
      File.write("#{directory}/spec/example_spec.rb", <<~RUBY)
        require_relative "support/shared"
        RSpec.describe "consumer" do
          it_behaves_like "a regression"
        end
      RUBY
      output, status =
        Open3.capture2e(
          { "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s },
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--require",
          Rails.root.join("script/ci/rspec_selection_audit.rb").to_s,
          "spec/example_spec.rb",
          chdir: directory,
        )
      expect(status.success?).to eq(false), output
      report = JSON.parse(File.read(Dir["#{directory}/tmp/rspec-mapping/audit-worker-*.json"].sole))
      expect(report["omitted_failures"]).to eq([])
      expect(report["failures"].size).to eq(1)
    end
  end

  it "preserves delegated cache dependencies through worker order and records shared inputs" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/tmp/rspec-mapping")
      FileUtils.mkdir_p("#{directory}/lib")
      FileUtils.mkdir_p("#{directory}/spec/integrity")
      FileUtils.mkdir_p("#{directory}/spec/requests")
      FileUtils.mkdir_p("#{directory}/frontend/discourse/app")
      File.write("#{directory}/frontend/discourse/app/input.js", '{"first":"good","second":"good"}')
      File.write("#{directory}/lib/reader.rb", <<~RUBY)
        class Reader
          class << self
            attr_reader :values
          end
        end
      RUBY
      File.write("#{directory}/lib/producer.rb", <<~RUBY)
        require "json"
        module Producer
          def self.values
            JSON.parse(File.read(File.expand_path("../frontend/discourse/app/input.js", __dir__))).merge("second" => "good")
          end
        end
      RUBY
      File.write("#{directory}/lib/loader.rb", <<~RUBY)
        require_relative "producer"
        class Reader
          def self.load!
            @values = Producer.values
          end
        end
      RUBY
      paths = { first: "spec/integrity/warm_spec.rb", second: "spec/requests/consumer_spec.rb" }
      paths.each { |name, path| File.write("#{directory}/#{path}", <<~RUBY) }
          require File.expand_path("lib/reader", Dir.pwd)
          require File.expand_path("lib/loader", Dir.pwd)
          RSpec.describe "#{name} consumer" do
            before { Reader.load! unless Reader.values }
            it("reads #{name}") { expect(Reader.values.fetch("#{name}")).to eq("good") }
          end
        RUBY
      consumer = "#{directory}/#{paths[:second]}"
      File.write(consumer, <<~RUBY + File.read(consumer))
        RSpec.describe "unrelated early group" do
          it("runs early") { expect(true).to eq(true) }
        end
      RUBY
      environment = {
        "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s,
        "GITHUB_SHA" => "a" * 40,
        "TEST_ENV_NUMBER" => nil,
        "RSPEC_MAPPING_DIRECTORY" => "#{directory}/tmp/rspec-mapping",
      }
      output, status =
        Open3.capture2e(
          environment,
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--order",
          "random:10",
          "--require",
          Rails.root.join("script/ci/rspec_mapping.rb").to_s,
          *paths.values,
          chdir: directory,
        )
      expect(status.success?).to eq(true), output
      File.write(
        "#{directory}/tmp/rspec-mapping/execution.json",
        JSON.generate(
          revision: "a" * 40,
          grouping_runtime_log: nil,
          workers: {
            multisite: paths.values,
          },
        ),
      )
      output, status =
        Open3.capture2e(
          environment.merge("RUBYOPT" => nil),
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "merge",
          chdir: directory,
        )
      expect(status.success?).to eq(true), output
      mapping = JSON.parse(File.read("#{directory}/tmp/rspec-mapping/mapping.json"))
      expect(mapping["dependencies"].keys).to contain_exactly(*paths.values)
      expect(mapping["shared_files"]).to include("frontend/discourse/app/input.js")
      expect(mapping["shared_files"]).not_to include(
        "lib/reader.rb",
        "lib/loader.rb",
        "lib/producer.rb",
      )
      expect(mapping["worker_specs"].sole).to contain_exactly(*paths.values)
      expect(mapping["dependencies"][paths[:second]]).not_to include("lib/producer.rb")
      loader = "#{directory}/lib/producer.rb"
      File.write(loader, File.read(loader).sub('"second" => "good"', '"second" => "broken"'))
      expect(
        RspecSourceStructure.matches?(
          path: loader,
          description: mapping["source_checks"]["lib/producer.rb"],
        ),
      ).to eq(true)
      output, status = Open3.capture2e("node", "-e", <<~JAVASCRIPT, chdir: directory)
          const fs = require("node:fs");
          const { select } = require(#{Rails.root.join(".github/scripts/select-rspec.cjs").to_s.to_json});
          const mapping = JSON.parse(fs.readFileSync("tmp/rspec-mapping/mapping.json"));
          console.log(JSON.stringify(select({mapping, revision: "b".repeat(40), inventory: #{paths.values.to_json}, changed: ["lib/producer.rb"]})));
        JAVASCRIPT
      expect(status.success?).to eq(true), output
      selection = JSON.parse(output)
      expect(selection["mode"]).to eq("subset")
      expect(selection["specs"]).to contain_exactly(*paths.values)
      output, status =
        Open3.capture2e(
          environment.merge("COLLECT_RSPEC_MAPPING" => nil),
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--order",
          "random:10",
          *selection["specs"],
          chdir: directory,
        )
      expect(status.success?).to eq(false), output
      expect(output).to include("3 examples, 1 failure")
    end
  end

  it "retains declarations and code executed during boot when validating source changes" do
    Dir.mktmpdir do |directory|
      path = "#{directory}/source.rb"
      original = "class Example\n  VALUE = 42\n  def self.value\n    VALUE.to_s\n  end\nend\n"
      File.write(path, original)
      description = RspecSourceStructure.describe(path)
      File.write(path, original.sub("VALUE.to_s", "VALUE.to_i"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(true)
      File.write(path, original.sub("42", "43"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original)
      description = RspecSourceStructure.describe(path, boot_lines: [4])
      File.write(path, original.sub("VALUE.to_s", "VALUE.to_i"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
      File.write(path, original.sub("def self.value", "def self.value(argument)"))
      expect(RspecSourceStructure.matches?(path:, description:)).to eq(false)
    end
  end

  it "merges complete worker mappings and rejects invalid collection" do
    Dir.mktmpdir do |directory|
      output_directory = "#{directory}/tmp/rspec-mapping"
      FileUtils.mkdir_p(output_directory)
      revision = "a" * 40
      worker = {
        version: 4,
        revision: revision,
        complete: true,
        spec_order: ["spec/example_spec.rb"],
        completed_groups: 1,
        boot_lines: {
        },
        shared_files: [],
        files: ["spec/example_spec.rb"],
        shared_globs: ["frontend/pretty-text/**/*.js"],
      }
      File.write(
        "#{output_directory}/execution.json",
        JSON.generate(
          revision:,
          grouping_runtime_log: nil,
          workers: {
            first: ["spec/example_spec.rb"],
            second: ["spec/example_spec.rb"],
          },
        ),
      )
      %w[first second].each do |name|
        File.write(
          "#{output_directory}/worker-#{name}.json",
          JSON.generate(
            worker.merge(
              identity: name,
              dependencies: {
                "spec/example_spec.rb" => ["lib/#{name}.rb"],
              },
            ),
          ),
        )
      end

      output, status =
        Open3.capture2e(
          {
            "GITHUB_SHA" => revision,
            "COLLECT_RSPEC_MAPPING" => nil,
            "RSPEC_SELECTION_AUDIT" => nil,
            "RUBYOPT" => nil,
          },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "merge",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      mapping = JSON.parse(File.read("#{output_directory}/mapping.json"))
      expect(mapping.fetch("dependencies").fetch("spec/example_spec.rb")).to contain_exactly(
        "lib/first.rb",
        "lib/second.rb",
      )
      expect(mapping.fetch("shared_globs")).to eq(["frontend/pretty-text/**/*.js"])

      %w[multisite retry].each do |name|
        File.write(
          "#{output_directory}/worker-#{name}.json",
          JSON.generate(
            worker.merge(
              identity: "multisite",
              multisite_only: name == "multisite",
              dependencies: {
                "spec/example_spec.rb" => ["lib/#{name}.rb"],
              },
            ),
          ),
        )
      end
      output, status =
        Open3.capture2e(
          {
            "GITHUB_SHA" => revision,
            "COLLECT_RSPEC_MAPPING" => nil,
            "RSPEC_SELECTION_AUDIT" => nil,
            "RUBYOPT" => nil,
          },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "merge",
          chdir: directory,
        )
      expect(status.success?).to eq(true), output
      mapping = JSON.parse(File.read("#{output_directory}/mapping.json"))
      expect(mapping.fetch("worker_specs")).to eq(Array.new(3) { ["spec/example_spec.rb"] })
      expect(mapping.fetch("dependencies").fetch("spec/example_spec.rb")).to contain_exactly(
        "lib/first.rb",
        "lib/second.rb",
        "lib/multisite.rb",
        "lib/retry.rb",
      )

      File.delete("#{output_directory}/worker-second.json")
      output, status =
        Open3.capture2e(
          {
            "GITHUB_SHA" => revision,
            "COLLECT_RSPEC_MAPPING" => nil,
            "RSPEC_SELECTION_AUDIT" => nil,
            "RUBYOPT" => nil,
          },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "merge",
          chdir: directory,
        )
      expect(status.success?).to eq(false)
      expect(output).to include("Incomplete RSpec mapping")

      File.write(
        "#{output_directory}/worker-second.json",
        JSON.generate(
          worker.merge(
            identity: "second",
            dependencies: {
              "spec/example_spec.rb" => ["lib/second.rb"],
            },
          ),
        ),
      )

      extra_worker =
        worker.merge(identity: "extra", dependencies: {}, spec_order: [], completed_groups: 0)
      [
        extra_worker.merge(complete: false),
        extra_worker.merge(revision: "b" * 40),
        extra_worker.merge(completed_groups: 1),
        extra_worker.merge(spec_order: ["spec/example_spec.rb"], completed_groups: 1),
      ].each do |invalid_worker|
        File.write("#{output_directory}/worker-invalid.json", JSON.generate(invalid_worker))

        output, status =
          Open3.capture2e(
            {
              "GITHUB_SHA" => revision,
              "COLLECT_RSPEC_MAPPING" => nil,
              "RSPEC_SELECTION_AUDIT" => nil,
              "RUBYOPT" => nil,
            },
            "ruby",
            Rails.root.join("script/ci/rspec_selection.rb").to_s,
            "merge",
            chdir: directory,
          )

        expect(status.success?).to eq(false)
        expect(output).to include("Incomplete RSpec mapping")
      end
    end
  end

  it "runs whole affected workers without moving mandatory specs into skipped slots" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/lib")
      FileUtils.mkdir_p("#{directory}/spec")
      FileUtils.mkdir_p("#{directory}/tmp")
      File.symlink(Rails.root.join("lib/turbo_tests"), "#{directory}/lib/turbo_tests")
      File.symlink(Rails.root.join("db"), "#{directory}/db")
      File.write(
        "#{directory}/lib/turbo_tests.rb",
        "Dir.chdir(#{Rails.root.to_s.inspect}) { require #{Rails.root.join("lib/turbo_tests.rb").to_s.inspect} }\n",
      )
      File.write("#{directory}/child.rb", <<~RUBY)
        require "json"
        require #{Rails.root.join("lib/turbo_tests/json_example.rb").to_s.inspect}
        require #{Rails.root.join("lib/turbo_tests/json_rows_formatter.rb").to_s.inspect}
      RUBY
      files = %w[a b c d e f].map { |name| "spec/#{name}_spec.rb" }
      files.each { |path| File.write("#{directory}/#{path}", <<~RUBY) }
          RSpec.describe #{path.inspect} do
            it "runs a regular example" do
              File.write("seen-\#{ENV.fetch('TEST_ENV_NUMBER')}-#{File.basename(path)}", "regular")
            end
            it "runs a multisite example", type: :multisite do
              File.write("seen-multisite-#{File.basename(path)}", "multisite")
            end
          end
        RUBY
      File.write(
        "#{directory}/tmp/turbo_rspec_runtime.log",
        files.each_with_index.map { |path, index| "#{path}:#{6 - index}\n" }.join,
      )
      File.write(
        "#{directory}/selection.json",
        JSON.generate(specs: files.first(2), cohort_specs: [files.second], full_multisite: true),
      )

      output, status =
        Open3.capture2e(
          {
            "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s,
            "PARALLEL_TEST_PROCESSORS" => "3",
            "DISCOURSE_TURBO_RSPEC_RETRY_AND_LOG_FLAKY_TESTS" => nil,
            "COLLECT_RSPEC_MAPPING" => nil,
            "RSPEC_SELECTION_AUDIT" => nil,
            "RUBYOPT" => nil,
            "SPEC_OPTS" => "--options /dev/null --require #{directory}/child.rb",
          },
          "ruby",
          Rails.root.join("bin/turbo_rspec").to_s,
          "--use-runtime-info",
          "--selection",
          "selection.json",
          "--execution-plan",
          "execution.json",
          *files,
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      execution = JSON.parse(File.read("#{directory}/execution.json"))
      expect(execution.fetch("workers").transform_values(&:sort)).to eq(
        "1" => [files.first],
        "2" => [files.second, files.fifth],
        "multisite" => files,
      )
      expect(execution.fetch("predicted_regular_specs")).to contain_exactly(
        files.first,
        files.second,
        files.fifth,
      )
      expect(execution.fetch("predicted_multisite_specs")).to eq(files)
      expect(Dir["#{directory}/seen-*"].map { |path| File.basename(path) }).to contain_exactly(
        "seen-1-a_spec.rb",
        "seen-2-b_spec.rb",
        "seen-2-e_spec.rb",
        *files.map { |path| "seen-multisite-#{File.basename(path)}" },
      )
    end
  end
end
