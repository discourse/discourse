# frozen_string_literal: true

describe ProblemCheck::AiImageCaptionAgent do
  subject(:check) { described_class.new }

  fab!(:vision_llm) do
    Fabricate(:llm_model, display_name: "Vision model", name: "vision-model", vision_enabled: true)
  end
  fab!(:text_llm) do
    Fabricate(:llm_model, display_name: "Text model", name: "text-model", vision_enabled: false)
  end

  before do
    SiteSetting.remove_override!(:ai_image_caption_agent)
    SiteSetting.refresh!
    enable_current_plugin
    caption_agent.update!(enabled: true, vision_enabled: true, default_llm_id: vision_llm.id)
    SiteSetting.ai_post_image_captions_enabled = true
  end

  def caption_agent
    AiAgent.find_by(id: SiteSetting.ai_image_caption_agent.to_i) ||
      Fabricate(:ai_agent, id: SiteSetting.ai_image_caption_agent.to_i)
  end

  it "returns no problem when post image captions are disabled" do
    SiteSetting.ai_post_image_captions_enabled = false
    caption_agent.update!(enabled: false)

    expect(check).to be_chill_about_it
  end

  it "returns no problem when discourse AI is disabled" do
    SiteSetting.discourse_ai_enabled = false
    caption_agent.update!(enabled: false)

    expect(check).to be_chill_about_it
  end

  it "returns no problem when the selected caption agent can generate image captions" do
    expect(check).to be_chill_about_it
  end

  it "returns no problem when the selected caption agent is disabled for AI bot" do
    caption_agent.update!(enabled: false)

    expect(check).to be_chill_about_it
  end

  it "returns a problem when the selected caption agent cannot include images" do
    caption_agent.update!(vision_enabled: false)

    result = check.call

    expect(result).to have_attributes(priority: "high", target: caption_agent.id)
    expect(result.message).to include("the agent cannot include image uploads")
  end

  it "returns a problem when the selected caption agent resolves to a missing LLM" do
    caption_agent.update!(default_llm_id: -99_999)

    result = check.call

    expect(result).to have_attributes(priority: "high", target: caption_agent.id)
    expect(result.message).to include("the agent does not resolve to an LLM")
  end

  it "returns a problem when the selected caption agent resolves to an LLM without image input" do
    caption_agent.update!(default_llm_id: text_llm.id)

    result = check.call

    expect(result).to have_attributes(priority: "high", target: caption_agent.id)
    expect(result.message).to include("the resolved LLM does not support image input")
  end

  it "returns a problem when the selected caption agent does not exist" do
    SiteSetting.provider.save("ai_image_caption_agent", -99_999, SiteSetting.types[:enum])
    SiteSetting.refresh!

    result = check.call

    expect(result).to have_attributes(priority: "high", target: -99_999)
    expect(result.message).to include("the selected agent does not exist")
  end
end
