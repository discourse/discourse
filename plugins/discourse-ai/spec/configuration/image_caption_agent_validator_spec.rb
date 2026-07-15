# frozen_string_literal: true

describe DiscourseAi::Configuration::ImageCaptionAgentValidator do
  fab!(:vision_llm) do
    Fabricate(:llm_model, display_name: "Vision model", name: "vision-model", vision_enabled: true)
  end
  fab!(:text_llm) do
    Fabricate(:llm_model, display_name: "Text model", name: "text-model", vision_enabled: false)
  end

  fab!(:valid_agent) do
    Fabricate(:ai_agent, enabled: true, vision_enabled: true, default_llm_id: vision_llm.id)
  end
  fab!(:disabled_agent) do
    Fabricate(:ai_agent, enabled: false, vision_enabled: true, default_llm_id: vision_llm.id)
  end
  fab!(:non_vision_agent) do
    Fabricate(:ai_agent, enabled: true, vision_enabled: false, default_llm_id: vision_llm.id)
  end
  fab!(:text_llm_agent) do
    Fabricate(:ai_agent, enabled: true, vision_enabled: true, default_llm_id: text_llm.id)
  end
  fab!(:missing_llm_agent) do
    Fabricate(:ai_agent, enabled: true, vision_enabled: true, default_llm_id: -99_999)
  end

  before { enable_current_plugin }

  let(:validator) { described_class.new(name: :ai_image_caption_agent) }

  it "accepts the default image caption agent setting value" do
    expect(validator.valid_value?("-26")).to eq(true)
  end

  it "accepts an enabled vision agent that uses a vision-capable LLM" do
    expect(validator.valid_value?(valid_agent.id)).to eq(true)
  end

  it "rejects a missing agent" do
    expect(validator.valid_value?(-99_999)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.image_caption.configuration.agent_missing"),
    )
  end

  it "rejects a disabled agent" do
    expect(validator.valid_value?(disabled_agent.id)).to eq(false)
    expect(validator.error_message).to eq(I18n.t("discourse_ai.image_caption.configuration.disabled"))
  end

  it "rejects an agent without vision enabled" do
    expect(validator.valid_value?(non_vision_agent.id)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.image_caption.configuration.agent_vision_disabled"),
    )
  end

  it "rejects an agent that resolves to an LLM without vision enabled" do
    expect(validator.valid_value?(text_llm_agent.id)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.image_caption.configuration.llm_vision_disabled"),
    )
  end

  it "rejects an agent that resolves to a missing LLM" do
    expect(validator.valid_value?(missing_llm_agent.id)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.image_caption.configuration.llm_missing"),
    )
  end

  it "validates assignments to the image caption agent site setting" do
    SiteSetting.ai_image_caption_agent = valid_agent.id

    expect(SiteSetting.ai_image_caption_agent).to eq(valid_agent.id.to_s)
    expect { SiteSetting.ai_image_caption_agent = text_llm_agent.id }.to raise_error(
      Discourse::InvalidParameters,
      /vision-capable LLM/,
    )
  end
end
