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
    let(:prompt) { agent.system_prompt }

    it "includes placeholder for concept list" do
      expect(prompt).to include("{inferred_concepts}")
    end

    it "specifies output format" do
      expect(prompt).to include("matching_concepts")
      expect(prompt).to include('{"matching_concepts": ["concept1", "concept3", "concept5"]}')
    end
  end

  describe "#response_format" do
    it "defines correct response format" do
      format = agent.response_format

      expect(format).to eq(
        [{ "array_type" => "string", "key" => "matching_concepts", "type" => "array" }],
      )
    end
  end
end
