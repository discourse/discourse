# frozen_string_literal: true

require_relative "../../../evals/lib/runners/data_explorer"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::DataExplorer do
  fab!(:llm, :fake_model)
  let(:execution_context) { DiscourseAi::Completions::ExecutionContext.new }
  let(:runner) { described_class.new("query_generation") }
  let(:eval_case) { OpenStruct.new(args: { input: "Show me signups by month" }) }

  def stub_submitted_query(name:, description:, sql:)
    submission = { name: name, description: description, sql: sql }
    bot = instance_double(DiscourseAi::Agents::Bot)

    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply) do |context, execution_context: nil|
      context.feature_context[DiscourseDataExplorer::Tools::SubmitQuery::CONTEXT_KEY] = submission
    end
  end

  describe "#run" do
    it "captures the query submitted through the Data Explorer submit tool" do
      stub_submitted_query(
        name: "Signups by month",
        description: "Counts user signups grouped by month.",
        sql: "SELECT date_trunc('month', created_at) AS month FROM users GROUP BY month;",
      )

      result = runner.run(eval_case, llm, execution_context: execution_context)

      expect(result[:raw]).to include("SELECT date_trunc")
      expect(result[:metadata][:name]).to eq("Signups by month")
      expect(result[:metadata][:description]).to eq("Counts user signups grouped by month.")
      expect(result[:metadata][:feature]).to eq("query_generation")
      expect(result[:raw]).not_to end_with(";")
    end
  end
end
