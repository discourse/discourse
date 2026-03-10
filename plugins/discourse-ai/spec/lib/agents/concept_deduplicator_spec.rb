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

    it "specifies output format" do
      expect(prompt).to include("streamlined_tags")
      expect(prompt).to include('"streamlined_tags": ["tag1", "tag3"]')
    end
  end

  describe "#response_format" do
    it "defines correct response format" do
      format = agent.response_format

      expect(format).to eq(
        [{ "array_type" => "string", "key" => "streamlined_tags", "type" => "array" }],
      )
    end
  end
end
