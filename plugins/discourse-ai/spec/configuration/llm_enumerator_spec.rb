# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmEnumerator do
  fab!(:fake_model)
  fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: fake_model.id) }
  fab!(:llm_model)
  fab!(:seeded_model)
  fab!(:automation) do
    Fabricate(:automation, script: "llm_report", name: "some automation", enabled: true)
  end

  before { enable_current_plugin }

  describe "#values_for_serialization" do
    it "returns an array for that can be used for serialization" do
      fake_model.destroy!

      expect(described_class.values_for_serialization).to contain_exactly(
        {
          id: seeded_model.id,
          name: seeded_model.display_name,
          vision_enabled: seeded_model.vision_enabled,
        },
        {
          id: llm_model.id,
          name: llm_model.display_name,
          vision_enabled: llm_model.vision_enabled,
        },
      )
    end
  end

  describe "#global_usage" do
    it "returns a hash of Llm models in use globally" do
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_helper_proofreader_persona = ai_persona.id
      SiteSetting.ai_helper_enabled = true
      expect(described_class.global_usage).to eq(
        fake_model.id => [{ type: :ai_helper }],
        fake_model.id => [
          { id: ai_persona.id, name: ai_persona.name, type: :ai_persona },
          { name: "Proofread text", type: :ai_helper },
        ],
      )
    end

    it "returns information about automation rules" do
      automation.fields.create!(
        component: "text",
        name: "model",
        metadata: {
          value: llm_model.id,
        },
        target: "script",
      )

      usage = described_class.global_usage

      expect(usage).to eq(
        fake_model.id => [{ id: ai_persona.id, name: ai_persona.name, type: :ai_persona }],
        llm_model.id => [{ id: automation.id, name: automation.name, type: :automation }],
      )
    end
  end
end
