# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::ConceptFinder do
  let(:persona) { described_class.new }

  before { enable_current_plugin }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    before do
      Fabricate(:inferred_concept, name: "programming")
      Fabricate(:inferred_concept, name: "testing")
      Fabricate(:inferred_concept, name: "ruby")
    end

    it "includes existing concepts when available" do
      prompt = persona.system_prompt

      InferredConcept.all.each { |concept| expect(prompt).to include(concept.name) }
    end

    it "handles empty existing concepts" do
      InferredConcept.destroy_all
      prompt = persona.system_prompt

      expect(prompt).not_to include("following concepts already exist")
      expect(prompt).to include("advanced concept tagging system")
    end

    it "limits existing concepts to 100" do
      manager = instance_double(DiscourseAi::InferredConcepts::Manager)
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:new).and_return(manager)
      allow(manager).to receive(:list_concepts).with(limit: 100).and_return(%w[concept1 concept2])

      persona.system_prompt
    end

    it "includes format instructions" do
      prompt = persona.system_prompt

      expect(prompt).to include('{"concepts": ["concept1", "concept2", "concept3"]}')
    end

    it "includes language preservation instruction" do
      prompt = persona.system_prompt

      expect(prompt).to include("original language of the text")
    end
  end

  describe "#response_format" do
    it "defines correct response format" do
      format = persona.response_format

      expect(format).to eq([{ "array_type" => "string", "key" => "concepts", "type" => "array" }])
    end
  end
end
