# frozen_string_literal: true

require_relative "../../../evals/lib/runners/data_explorer"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::DataExplorer do
  fab!(:llm, :fake_model)
  let(:execution_context) { DiscourseAi::Completions::ExecutionContext.new }
  let(:runner) { described_class.new("query_generation") }
  let(:eval_case) { OpenStruct.new(args: { input: "Show me signups by month" }) }

  def stub_structured_response(name:, description:, sql:)
    payload = { name: name, description: description, sql: sql }
    structured =
      instance_double(DiscourseAi::Completions::StructuredOutput).tap do |double|
        allow(double).to receive(:read_buffered_property) { |key| payload[key] }
      end

    stub_runner_bot { |blk| blk.call(structured, nil, :structured_output) }
  end

  describe "#run" do
    it "captures name, description, and sql separately" do
      stub_structured_response(
        name: "Signups by month",
        description: "Counts user signups grouped by month.",
        sql: "SELECT date_trunc('month', created_at) AS month FROM users GROUP BY month",
      )

      result = runner.run(eval_case, llm, execution_context: execution_context)

      expect(result[:raw]).to include("SELECT date_trunc")
      expect(result[:metadata][:name]).to eq("Signups by month")
      expect(result[:metadata][:description]).to eq("Counts user signups grouped by month.")
      expect(result[:metadata][:feature]).to eq("query_generation")
    end
  end
end
