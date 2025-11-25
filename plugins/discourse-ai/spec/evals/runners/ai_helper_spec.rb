# frozen_string_literal: true

require_relative "../../../evals/lib/runners/ai_helper"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::AiHelper do
  describe "#run" do
    let(:llm) { Fabricate.build(:fake_model) }
    let(:eval_case) { OpenStruct.new(args: { input: "We need new titles." }) }
    let(:titles_persona) { DiscourseAi::Personas::TitlesGenerator.new }
    let(:runner) { described_class.new("title_suggestions") }

    before do
      stub_runner_bot(persona: titles_persona) do |blk|
        structured_output =
          instance_double(
            DiscourseAi::Completions::StructuredOutput,
            read_buffered_property: ["Title One", "Title Two <input>ignored</input>"],
          )
        blk.call(structured_output, nil, :structured_output)
      end
    end

    it "returns newline-separated suggestions when the helper outputs an array" do
      result = runner.run(eval_case, llm)

      lines = result[:raw].split("\n")
      expect(lines).to contain_exactly("Title One", "Title Two ignored")
      expect(result[:metadata]).to include(feature_name: "title_suggestions")
    end
  end
end
