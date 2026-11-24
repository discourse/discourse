# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::ConceptFinder do
  let(:agent) { described_class.new }

  before { enable_current_plugin }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    it "is static across concept additions and canonicalizes to default_locale" do
      SiteSetting.default_locale = "fr"
      prompt_before = agent.system_prompt

      Fabricate(:inferred_concept, name: "programming")
      Fabricate(:inferred_concept, name: "testing")

      prompt_after = agent.system_prompt

      expect(prompt_after).to eq(prompt_before)
      expect(prompt_after).to include("fr")
      expect(prompt_after).to include("concept_id")
      expect(prompt_after).to include("proposed_new")
      expect(prompt_after).not_to include("programming")
    end
  end

  describe "#response_format" do
    it "defines strict matches and proposed_new object arrays" do
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
          {
            "key" => "proposed_new",
            "type" => "array",
            "array_type" => "object",
            "max_items" => 3,
            "items" => {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[name description parent_concept_id],
              "properties" => {
                "name" => {
                  "type" => "string",
                },
                "description" => {
                  "type" => "string",
                },
                "parent_concept_id" => {
                  "type" => "integer",
                },
              },
            },
          },
        ],
      )
    end
  end
end
