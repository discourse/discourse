# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::ConceptMatcher do
  let(:agent) { described_class.new }

  before { enable_current_plugin }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    it "uses a static prompt without template interpolation for concept lists" do
      prompt = agent.system_prompt

      expect(prompt).not_to include("{inferred_concepts}")
      expect(prompt).to include("candidates")
      expect(prompt).to include("concept_id")
    end
  end

  describe "#response_format" do
    it "defines a strict matches object array" do
      expect(agent.response_format).to eq(
        [
          {
            "key" => "matches",
            "type" => "array",
            "array_type" => "object",
            "max_items" => 7,
            "items" => {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[concept_id relevance primary],
              "properties" => {
                "concept_id" => {
                  "type" => "integer",
                },
                "relevance" => {
                  "type" => "number",
                },
                "primary" => {
                  "type" => "boolean",
                },
              },
            },
          },
        ],
      )
    end
  end
end
