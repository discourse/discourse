# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::ConceptDeduplicator do
  let(:agent) { described_class.new }

  before { enable_current_plugin }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    let(:prompt) { agent.system_prompt }

    it "specifies merges and reparents output instructions and locale" do
      expect(prompt).to include("merges")
      expect(prompt).to include("canonical_id")
      expect(prompt).to include("merge_ids")
      expect(prompt).to include("reparents")
      expect(prompt).to include(SiteSetting.default_locale)
    end
  end

  describe "#response_format" do
    it "defines strict schemas for merges and reparents" do
      format = agent.response_format

      expect(format).to eq(
        [
          {
            "key" => "merges",
            "type" => "array",
            "array_type" => "object",
            "items" => {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[canonical_id merge_ids description],
              "properties" => {
                "canonical_id" => {
                  "type" => "integer",
                },
                "merge_ids" => {
                  "type" => "array",
                  "items" => {
                    "type" => "integer",
                  },
                },
                "description" => {
                  "type" => "string",
                },
              },
            },
          },
          {
            "key" => "reparents",
            "type" => "array",
            "array_type" => "object",
            "items" => {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[concept_id parent_concept_id],
              "properties" => {
                "concept_id" => {
                  "type" => "integer",
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
