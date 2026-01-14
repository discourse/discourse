# frozen_string_literal: true

require_relative "../../../evals/lib/runners/discoveries"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::Discoveries do
  fab!(:llm, :fake_model)

  before { stub_runner_bot(response: "Search overview") }

  describe "#run" do
    it "returns a discovery payload with the model output" do
      runner = described_class.new("discoveries")
      result = runner.run(OpenStruct.new(args: { query: "chat integrations" }), llm)

      expect(result[:raw]).to eq("Search overview")
      expect(result[:metadata]).to include(query: "chat integrations")
    end

    it "evaluates each provided case" do
      runner = described_class.new("discoveries")
      results =
        runner.run(
          OpenStruct.new(args: { cases: [{ query: "best themes" }, { query: "login security" }] }),
          llm,
        )

      expect(results.length).to eq(2)
      expect(results.last[:metadata]).to include(query: "login security")
    end

    it "raises when the query is missing" do
      runner = described_class.new("discoveries")

      expect { runner.run(OpenStruct.new(args: {}), llm) }.to raise_error(
        ArgumentError,
        /require :query/,
      )
    end
  end
end
