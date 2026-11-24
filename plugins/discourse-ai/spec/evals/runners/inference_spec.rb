# frozen_string_literal: true

require_relative "../../../evals/lib/runners/inference"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::Inference do
  fab!(:llm, :fake_model)
  let(:execution_context) { DiscourseAi::Completions::ExecutionContext.new }

  let(:structured_output) { instance_double(DiscourseAi::Completions::StructuredOutput) }

  before do
    stub_runner_bot(agent: DiscourseAi::Agents::ConceptFinder.new) do |blk|
      blk.call(structured_output, nil, :structured_output)
    end
  end

  describe "#run" do
    it "returns newline separated concepts for generate_concepts" do
      allow(structured_output).to receive(:read_buffered_property).with(:matches).and_return(
        [{ "concept_id" => 1, "relevance" => 0.95, "primary" => true }],
      )
      allow(structured_output).to receive(:read_buffered_property).with(:proposed_new).and_return(
        [{ "name" => "concept_b", "description" => "Observability dashboards" }],
      )

      eval_case =
        OpenStruct.new(
          args: {
            input: "This topic covers deployment pipelines and observability dashboards.",
            existing_concepts: %w[concept_a other_concept],
          },
        )

      runner = described_class.new("generate_concepts")
      result = runner.run(eval_case, llm, execution_context: execution_context)

      expect(result[:raw]).to eq("concept_a\nconcept_b")
    end

    it "uses provided concept candidates for match_concepts" do
      allow(structured_output).to receive(:read_buffered_property).with(:matches).and_return(
        [
          { "concept_id" => 1, "relevance" => 0.95, "primary" => true },
          { "concept_id" => 2, "relevance" => 0.8, "primary" => false },
        ],
      )
      allow(structured_output).to receive(:read_buffered_property).with(:proposed_new).and_return(
        [{ "name" => "ignored_new", "description" => "Should not be returned" }],
      )

      eval_case =
        OpenStruct.new(args: { input: "Moderation queue updates", concepts: %w[queue ai] })
      runner = described_class.new("match_concepts")
      expect(runner.run(eval_case, llm, execution_context: execution_context)[:raw]).to eq(
        "queue\nai",
      )
    end

    it "requires concepts for deduplicate_concepts" do
      runner = described_class.new("deduplicate_concepts")
      expect {
        runner.run(OpenStruct.new(args: {}), llm, execution_context: execution_context)
      }.to raise_error(ArgumentError, /requires :concepts/)
    end
  end
end
