# frozen_string_literal: true
require "json"
require "tmpdir"
require "fileutils"
require_relative "../../script/ci/dependency_graph"
require_relative "../../script/ci/test_mapping"
require_relative "../../script/ci/test_selection"

RSpec.describe TestSelection::DependencyGraph do
  it "preserves dependency direction and test bindings through JSON serialization" do
    graph = described_class.new
    graph.record(source: "lib/consumer.rb", dependencies: ["lib/producer.rb"])
    graph.record_test(file: "spec/consumer_spec.rb", dependencies: ["lib/consumer.rb"])
    graph.record_test(file: "spec/producer_spec.rb", dependencies: ["lib/producer.rb"])
    graph.record_test(file: "spec/unrelated_spec.rb", dependencies: ["lib/unrelated.rb"])
    serialized = JSON.parse(JSON.generate("graph" => graph.to_h, "tests" => graph.encoded_tests))

    decoded =
      described_class.new(serialized: serialized.fetch("graph"), tests: serialized.fetch("tests"))

    expect(decoded.affected_tests(decoded.affected_sources(["lib/producer.rb"]))).to eq(
      "spec/consumer_spec.rb" => ["lib/consumer.rb"],
      "spec/producer_spec.rb" => ["lib/producer.rb"],
    )
    expect(decoded.affected_tests(decoded.affected_sources(["lib/consumer.rb"]))).to eq(
      "spec/consumer_spec.rb" => ["lib/consumer.rb"],
    )
  end

  it "terminates cycles while retaining both sources" do
    graph = described_class.new
    graph.record(source: "lib/a.rb", dependencies: ["lib/b.rb"])
    graph.record(source: "lib/b.rb", dependencies: ["lib/a.rb"])
    decoded = described_class.new(serialized: JSON.parse(JSON.generate(graph.to_h)))

    expect(decoded.affected_sources(["lib/a.rb"])).to contain_exactly("lib/a.rb", "lib/b.rb")
  end

  it "merges dense dependencies and shared test bindings across different path indexes" do
    graph = described_class.new
    graph.record(source: "lib/consumer.rb", dependencies: ["lib/producer.rb"])
    graph.record_test(file: "spec/shared_spec.rb", dependencies: ["lib/consumer.rb"])
    graph.record_test(file: "spec/unrelated_spec.rb", dependencies: ["lib/unrelated.rb"])
    incoming = described_class.new
    incoming.record(source: "lib/empty.rb", dependencies: [])
    inputs = Array.new(128) { |index| "lib/input_#{index}.rb" }
    sources = Array.new(128) { |index| "lib/source_#{index}.rb" }
    sources.each { |source| incoming.record(source: source, dependencies: inputs) }
    incoming.record_test(file: "spec/shared_spec.rb", dependencies: sources)
    incoming.record_test(file: "spec/last_spec.rb", dependencies: [sources.last])
    serialized =
      JSON.parse(JSON.generate("graph" => incoming.to_h, "tests" => incoming.encoded_tests))

    graph.merge(serialized: serialized.fetch("graph"), tests: serialized.fetch("tests"))

    expect(
      graph.affected_tests(graph.affected_sources([inputs.last])).transform_values(&:sort),
    ).to eq("spec/shared_spec.rb" => sources.sort, "spec/last_spec.rb" => [sources.last])
    expect(graph.affected_tests(graph.affected_sources(["lib/producer.rb"]))).to eq(
      "spec/shared_spec.rb" => ["lib/consumer.rb"],
    )
    expect(graph.paths).to include("lib/empty.rb")
  end

  it "rejects references outside the incoming graph before modifying existing dependencies" do
    graph = described_class.new
    graph.record(source: "lib/consumer.rb", dependencies: ["lib/producer.rb"])
    graph.record_test(file: "spec/consumer_spec.rb", dependencies: ["lib/consumer.rb"])
    original = { "graph" => graph.to_h, "tests" => graph.encoded_tests }
    incoming = { "version" => 1, "paths" => ["lib/new.rb"], "callers" => [[]] }

    expect do
      graph.merge(serialized: incoming, tests: { "spec/new_spec.rb" => [1] })
    end.to raise_error(ArgumentError)

    expect("graph" => graph.to_h, "tests" => graph.encoded_tests).to eq(original)
  end

  shared_examples "an incoming graph fragment" do |missing:|
    it "rejects missing #{missing} before modifying existing dependencies" do
      graph = described_class.new
      graph.record(source: "lib/consumer.rb", dependencies: ["lib/producer.rb"])
      graph.record_test(file: "spec/consumer_spec.rb", dependencies: ["lib/consumer.rb"])
      original = { "graph" => graph.to_h, "tests" => graph.encoded_tests }
      fragment = { serialized: { "version" => 1, "paths" => [], "callers" => [] }, tests: {} }
      fragment[missing] = nil

      expect { graph.merge(**fragment) }.to raise_error(ArgumentError)

      expect("graph" => graph.to_h, "tests" => graph.encoded_tests).to eq(original)
    end
  end

  it_behaves_like "an incoming graph fragment", missing: :serialized
  it_behaves_like "an incoming graph fragment", missing: :tests

  it "keeps dense dependencies compact without losing high numbered sources" do
    inputs = Array.new(128) { |index| "lib/input_#{index}.rb" }
    sources = Array.new(128) { |index| "lib/source_#{index}.rb" }
    graph = described_class.new
    sources.each { |source| graph.record(source: source, dependencies: inputs) }
    graph.record_test(file: "spec/shared_spec.rb", dependencies: sources)
    graph.record_test(file: "spec/last_spec.rb", dependencies: [sources.last])
    graph.record_test(file: "spec/unrelated_spec.rb", dependencies: ["lib/unrelated.rb"])

    serialized = JSON.generate("graph" => graph.to_h, "tests" => graph.encoded_tests)
    data = JSON.parse(serialized)
    decoded = described_class.new(serialized: data.fetch("graph"), tests: data.fetch("tests"))
    selected = decoded.affected_tests(decoded.affected_sources([inputs.first]))

    expect(serialized.bytesize).to be < 100_000
    expect(selected.transform_values(&:sort)).to eq(
      "spec/shared_spec.rb" => sources.sort,
      "spec/last_spec.rb" => [sources.last],
    )
  end

  it "rejects malformed serialized dependencies" do
    valid = { "version" => 1, "paths" => ["lib/a.rb"], "callers" => [[]] }
    [[-1], [1], [0, 0], [0.0], "0", "2", nil].each do |row|
      expect { described_class.new(serialized: valid.merge("callers" => [row])) }.to raise_error(
        ArgumentError,
      )
    end
    expect {
      described_class.new(serialized: valid.merge("paths" => %w[lib/a.rb lib/a.rb]))
    }.to raise_error(ArgumentError)
  end

  it "rejects invalid test references before planning a subset" do
    mapping = {
      "version" => 3,
      "complete" => true,
      "revision" => "a" * 40,
      "environment" => "core",
      "sources" => ["lib/a.rb"],
      "initialization_sources" => [],
      "shared_files" => [],
      "tests" => {
        "spec/a_spec.rb" => [1],
      },
      "dependency_graph" => {
        "version" => 1,
        "paths" => ["lib/a.rb"],
        "callers" => [[]],
      },
    }
    input = {
      "revision" => "b" * 40,
      "mode" => "select",
      "main" => false,
      "changes" => ["lib/a.rb"],
      "test_changes" => [],
      "deleted_tests" => [],
      "jobs" => {
        "core" => {
          "inventory" => ["spec/a_spec.rb"],
          "environment" => "core",
          "mapping_changes" => [],
          "verified_sources" => ["lib/a.rb"],
          "mapping" => mapping,
        },
      },
    }

    expect { TestSelection::Planner.new(input).plan }.to raise_error(ArgumentError)
  end

  it "routes tests affected through dependencies collected in different parts" do
    Dir.mktmpdir("dependency-parts-") do |directory|
      Dir.chdir(directory) do
        FileUtils.mkdir_p(%w[lib spec parts execution])
        %w[producer shared consumer].each { |name| File.write("lib/#{name}.rb", "nil\n") }
        files = %w[spec/a_spec.rb spec/b_spec.rb spec/unrelated_spec.rb]
        files.each { |file| File.write(file, "") }
        catalog = {
          "revision" => "a" * 40,
          "jobs" => {
            "core" => {
              "inventory" => files,
              "environment" => "core",
              "command" => ["rspec"],
            },
          },
        }
        consumer = described_class.new
        consumer.record(source: "lib/consumer.rb", dependencies: ["lib/shared.rb"])
        consumer.record_test(file: files.first, dependencies: [])
        consumer.record_test(file: files.last, dependencies: [])
        compact = described_class.new
        compact.record(source: "lib/producer.rb", dependencies: [])
        compact.record(source: "lib/shared.rb", dependencies: ["lib/producer.rb"])
        compact.record_test(file: files[1], dependencies: ["lib/shared.rb"])
        parts = [
          {
            "version" => 5,
            "files" => [files.first, files.last],
            "dependencies" => {
              files.first => ["lib/consumer.rb"],
              files.last => [],
            },
            "dependency_graph" => consumer.to_h,
            "tests" => consumer.encoded_tests,
          },
          {
            "version" => 5,
            "files" => [files[1]],
            "dependencies" => {
            },
            "dependency_graph" => compact.to_h,
            "tests" => compact.encoded_tests,
          },
        ]
        parts.each_with_index do |part, index|
          record = {
            "revision" => catalog.fetch("revision"),
            "identity" => index.to_s,
            "pid" => index + 1,
            "files" => part.fetch("files"),
          }
          mapping =
            record.merge(part).merge(
              "environment" => "core",
              "complete" => true,
              "boot_lines" => {
              },
              "initialization_sources" => [],
              "shared_files" => [],
            )
          File.write("execution/rspec-#{index + 1}.json", JSON.generate(record))
          File.write("parts/worker-#{index + 1}.json", JSON.generate(mapping))
        end

        TestMapping.merge(
          catalog: catalog,
          job_name: "core",
          directory: "parts",
          execution_directory: "execution",
          output: "mapping.json",
        )
        mapping = JSON.parse(File.read("mapping.json"))
        input = {
          "revision" => "b" * 40,
          "mode" => "select",
          "main" => false,
          "changes" => ["lib/producer.rb"],
          "test_changes" => [],
          "deleted_tests" => [],
          "jobs" => {
            "core" =>
              catalog
                .fetch("jobs")
                .fetch("core")
                .merge(
                  "mapping" => mapping,
                  "mapping_changes" => [],
                  "verified_sources" => ["lib/producer.rb"],
                ),
          },
        }

        expect(TestSelection::Planner.new(input).plan.fetch("files")).to eq(files.first(2))
      end
    end
  end
end
