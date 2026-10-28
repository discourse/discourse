# frozen_string_literal: true

require "rails_helper"
require "crystalball"
require "open3"
require "tmpdir"

RSpec.describe Crystalball do
  it "records outer setup and nested shared examples against the including spec" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/spec/support")
      FileUtils.mkdir_p("#{directory}/lib")
      File.write("#{directory}/lib/definition.rb", "class Definition\n  VALUE = 42\nend\n")
      %w[setup body].each { |name| File.write("#{directory}/lib/#{name}.rb", <<~RUBY) }
          module #{name.capitalize}
            def self.value
              42.to_s
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
      expect(worker["dependencies"]["spec/example_spec.rb"]).to include(
        "lib/setup.rb",
        "lib/body.rb",
        "lib/definition.rb",
        "spec/support/shared.rb",
      )
    end
  end

  it "passes a selected list to the runner and skips an empty selection" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/tmp/rspec-mapping")
      FileUtils.mkdir_p("#{directory}/spec/views")
      FileUtils.mkdir_p("#{directory}/bin")
      File.write("#{directory}/spec/views/example.html.erb_spec.rb", "")
      File.write("#{directory}/bin/turbo_rspec", <<~RUBY)
        #!/usr/bin/env ruby
        require "json"
        File.write("arguments.json", JSON.generate(ARGV))
      RUBY
      FileUtils.chmod("+x", "#{directory}/bin/turbo_rspec")
      selection_path = "#{directory}/tmp/rspec-mapping/selection.json"
      revision = "b" * 40
      selection = {
        mode: "subset",
        revision: revision,
        specs: ["spec/views/example.html.erb_spec.rb"],
      }
      File.write(selection_path, JSON.generate(selection))

      output, status =
        Open3.capture2e(
          { "GITHUB_SHA" => revision },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "run",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      expect(JSON.parse(File.read("#{directory}/arguments.json"))).to eq(
        %w[--use-runtime-info --format=progress spec/views/example.html.erb_spec.rb],
      )

      File.delete("#{directory}/arguments.json")
      File.write(selection_path, JSON.generate(selection.merge(specs: [])))

      output, status =
        Open3.capture2e(
          { "GITHUB_SHA" => revision },
          "ruby",
          Rails.root.join("script/ci/rspec_selection.rb").to_s,
          "run",
          chdir: directory,
        )

      expect(status.success?).to eq(true), output
      expect(File.exist?("#{directory}/arguments.json")).to eq(false)
    end
  end

  it "merges complete worker mappings and rejects invalid collection" do
    Dir.mktmpdir do |directory|
      output_directory = "#{directory}/tmp/rspec-mapping"
      FileUtils.mkdir_p(output_directory)
      revision = "a" * 40
      worker = {
        version: 1,
        revision: revision,
        complete: true,
        shared_globs: ["frontend/pretty-text/**/*.js"],
      }
      %w[first second].each do |name|
        File.write(
          "#{output_directory}/worker-#{name}.json",
          JSON.generate(
            worker.merge(dependencies: { "spec/example_spec.rb" => ["lib/#{name}.rb"] }),
          ),
        )
      end

      output, status =
        Open3.capture2e(
          { "GITHUB_SHA" => revision },
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

      [worker.merge(complete: false), worker.merge(revision: "b" * 40)].each do |invalid_worker|
        File.write("#{output_directory}/worker-invalid.json", JSON.generate(invalid_worker))

        output, status =
          Open3.capture2e(
            { "GITHUB_SHA" => revision },
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
end
