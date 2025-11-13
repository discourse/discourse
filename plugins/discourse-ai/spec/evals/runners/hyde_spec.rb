# frozen_string_literal: true

require_relative "../../../evals/lib/runners/hyde"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::Hyde do
  fab!(:llm, :fake_model)

  before { stub_runner_bot(response: "Hypothetical post") }

  describe "#run" do
    it "returns a payload for a single query" do
      runner = described_class.new("hyde")
      result = runner.run(OpenStruct.new(args: { query: "How to theme Discourse" }), llm)

      expect(result[:raw]).to eq("Hypothetical post")
      expect(result[:metadata]).to include(query: "How to theme Discourse")
    end

    it "evaluates multiple cases when provided" do
      runner = described_class.new("hyde")
      results =
        runner.run(
          OpenStruct.new(
            args: {
              cases: [{ query: "Discourse S3 backups" }, { query: "Plugins" }],
            },
          ),
          llm,
        )

      expect(results.length).to eq(2)
      expect(results.first[:raw]).to eq("Hypothetical post")
      expect(results.first[:metadata]).to include(query: "Discourse S3 backups")
    end

    it "raises when the query is missing" do
      runner = described_class.new("hyde")

      expect { runner.run(OpenStruct.new(args: {}), llm) }.to raise_error(
        ArgumentError,
        /require :query/,
      )
    end
  end
end
