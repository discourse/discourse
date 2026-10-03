# frozen_string_literal: true

require_relative "../../evals/lib/cli"
require_relative "../../evals/lib/eval"

RSpec.describe DiscourseAi::Evals::Cli do
  describe ".parse_options!" do
    it "parses a positive eval limit" do
      cli = nil
      stub_const(Object, :ARGV, %w[--limit 2]) do
        cli = described_class.parse_options!(stub(valid_feature_key?: true))
      end

      expect(cli.limit).to eq(2)
    end

    it "rejects a non-positive eval limit" do
      stub_const(Object, :ARGV, %w[--limit 0]) do
        expect { described_class.parse_options!(stub(valid_feature_key?: true)) }.to raise_error(
          SystemExit,
        ).and output("--limit must be a positive integer.\n").to_stderr
      end
    end
  end

  describe "#select_evals" do
    it "limits evals after applying feature and name filters" do
      cli = described_class.new
      cli.feature_key = "summarization:topic_summaries"
      cli.eval_name = "matching"
      cli.limit = 1
      matching = Struct.new(:id, :feature).new("matching", cli.feature_key)
      wrong_name = Struct.new(:id, :feature).new("extra", cli.feature_key)
      other = Struct.new(:id, :feature).new("other", "translation:post")

      expect(cli.select_evals([other, wrong_name, matching])).to eq([matching])
    end
  end

  describe "#select_dataset_evals" do
    it "loads and limits dataset evals while preserving their order" do
      cli = described_class.new
      cli.limit = 2
      evals = %i[first second third]
      allow(DiscourseAi::Evals::Eval).to receive(:from_dataset_csv).with(
        path: "evals.csv",
        feature: "summarization:topic_summaries",
      ).and_return(evals)

      expect(
        cli.select_dataset_evals(path: "evals.csv", feature: "summarization:topic_summaries"),
      ).to eq(%i[first second])
    end
  end
end
