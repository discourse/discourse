# frozen_string_literal: true

require_relative "../../evals/lib/eval"

RSpec.describe DiscourseAi::Evals::Eval do
  around do |example|
    Dir.mktmpdir do |dir|
      @cases_dir = dir
      stub_const(described_class, :CASES_GLOB, File.join(dir, "*/*.yml")) { example.run }
    end
  end

  describe ".from_dataset_csv" do
    let(:csv_path) { File.join(@cases_dir, "dataset.csv") }

    before { File.write(csv_path, <<~CSV) }
          content,expected_output
          call this number for free money,true
          hey there is a bug on version 3,false
        CSV

    it "builds evals for each row with expected outputs" do
      evals = described_class.from_dataset_csv(path: csv_path, feature: "spam:inspect_posts")

      expect(evals.length).to eq(2)
      expect(evals.first.args[:input]).to include("free money")
      expect(evals.first.expected_output).to eq("true")
      expect(evals.last.expected_output).to eq("false")
    end
  end

  describe ".available_cases" do
    it "loads eval instances sorted by file path" do
      write_case("set-one", "second", "id" => "second", "feature" => "mod:second")
      write_case("set-one", "first", "id" => "first", "feature" => "mod:first")

      cases = described_class.available_cases

      expect(cases.map(&:id)).to eq(%w[first second])
      expect(cases).to all(be_a(described_class))
    end
  end

  describe "#initialize" do
    it "raises when the feature key is missing" do
      path = write_case("invalid", "missing-feature", "feature" => "")

      expect { described_class.new(path: path) }.to raise_error(
        ArgumentError,
        /must define a 'feature' key/,
      )
    end

    it "expands relative *_path args to absolute paths" do
      folder = File.join(@cases_dir, "path-case")
      FileUtils.mkdir_p(folder)
      File.write(File.join(folder, "input.txt"), "hello world")

      path =
        write_case(
          "path-case",
          "example",
          "args" => {
            "input_path" => "input.txt",
            "other" => "value",
          },
        )

      eval_case = described_class.new(path: path)

      expect(eval_case.args[:input_path]).to eq(File.expand_path(File.join(folder, "input.txt")))
      expect(eval_case.args[:other]).to eq("value")
    end

    it "symbolizes array args elements" do
      path =
        write_case(
          "array-case",
          "example",
          "args" => [{ "prompt" => "Hello" }, { "expected_output" => "Hi" }],
        )

      eval_case = described_class.new(path: path)

      expect(eval_case.args).to eq([{ prompt: "Hello" }, { expected_output: "Hi" }])
    end

    it "compiles expected_output_regex with multiline mode" do
      path = write_case("regex-case", "example", "expected_output_regex" => "line\\nnext")

      eval_case = described_class.new(path: path)

      expect(eval_case.expected_output_regex).to be_a(Regexp)
      expect(eval_case.expected_output_regex.source).to eq("line\\nnext")
      expect(eval_case.expected_output_regex.options & Regexp::MULTILINE).not_to eq(0)
    end

    it "defaults args to an empty hash when not provided" do
      path = write_case("no-args", "example", "args" => nil)

      eval_case = described_class.new(path: path)

      expect(eval_case.args).to eq({})
    end
  end

  def write_case(folder, name, overrides = {})
    case_dir = File.join(@cases_dir, folder)
    FileUtils.mkdir_p(case_dir)

    data = {
      "id" => "#{name}-id",
      "name" => "#{name} name",
      "description" => "example description",
      "feature" => "module:#{name}",
    }.merge(overrides)

    data["args"] = { "prompt" => "Hello" } unless overrides.key?("args")

    path = File.join(case_dir, "#{name}.yml")
    File.write(path, data.to_yaml)
    path
  end
end
