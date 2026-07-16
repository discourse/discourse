# frozen_string_literal: true

describe DiscourseAi::Configuration::ImageCaptionEnabledValidator do
  fab!(:vision_llm) do
    Fabricate(:llm_model, display_name: "Vision model", name: "vision-model", vision_enabled: true)
  end
  fab!(:valid_agent) do
    Fabricate(:ai_agent, enabled: false, vision_enabled: true, default_llm_id: vision_llm.id)
  end
  fab!(:non_vision_agent) do
    Fabricate(:ai_agent, enabled: true, vision_enabled: false, default_llm_id: vision_llm.id)
  end

  before { enable_current_plugin }

  after do
    SiteSetting.ai_post_image_captions_enabled = false
    SiteSetting.remove_override!(:ai_image_caption_agent)
    SiteSetting.refresh!
  end

  def set_caption_agent(agent)
    SiteSetting.provider.save("ai_image_caption_agent", agent.id, SiteSetting.types[:enum])
    SiteSetting.refresh!
  end

  it "accepts an agent that is disabled for AI bot" do
    set_caption_agent(valid_agent)

    SiteSetting.ai_post_image_captions_enabled = true

    expect(SiteSetting.ai_post_image_captions_enabled).to eq(true)
  end

  it "rejects enabling image captions when the selected agent cannot generate image captions" do
    set_caption_agent(non_vision_agent)

    expect { SiteSetting.ai_post_image_captions_enabled = true }.to raise_error(
      Discourse::InvalidParameters,
      /image uploads enabled/,
    )
  end

  it "allows disabling image captions when the selected agent cannot generate image captions" do
    set_caption_agent(non_vision_agent)

    SiteSetting.ai_post_image_captions_enabled = false

    expect(SiteSetting.ai_post_image_captions_enabled).to eq(false)
  end
end
