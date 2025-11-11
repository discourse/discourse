# frozen_string_literal: true

require_relative "../../../evals/lib/runners/inference"

RSpec.describe DiscourseAi::Evals::Runners::Inference do
  fab!(:llm, :fake_model)

  let(:structured_output) do
    instance_double(
      DiscourseAi::Completions::StructuredOutput,
      read_buffered_property: %w[concept_a concept_b],
    )
  end
  let(:bot_double) { instance_double(DiscourseAi::Personas::Bot, persona: persona_instance) }
  let(:persona_instance) { DiscourseAi::Personas::ConceptFinder.new }

  before do
    allow(AiPersona).to receive(:find_by_id_from_cache).and_return(nil)
    allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
    allow(bot_double).to receive(:reply) do |_context, &block|
      block.call(structured_output, nil, :structured_output)
    end
  end

  describe "#run" do
    it "returns newline separated concepts for generate_concepts" do
      eval_case =
        OpenStruct.new(
          args: {
            input: "This topic covers deployment pipelines and observability dashboards.",
          },
        )

      runner = described_class.new("generate_concepts")
      result = runner.run(eval_case, llm)

      expect(result).to eq("concept_a\nconcept_b")
    end

    it "uses provided concept candidates for match_concepts" do
      eval_case =
        OpenStruct.new(args: { input: "Moderation queue updates", concepts: %w[queue ai] })
      runner = described_class.new("match_concepts")
      expect(runner.run(eval_case, llm)).to eq("concept_a\nconcept_b")
    end

    it "requires concepts for deduplicate_concepts" do
      runner = described_class.new("deduplicate_concepts")
      expect do runner.run(OpenStruct.new(args: {}), llm) end.to raise_error(
        ArgumentError,
        /requires :concepts/,
      )
    end
  end
end
