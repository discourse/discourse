#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Image do
  let(:progress_blk) { Proc.new {} }
  let(:prompts) { ["a pink cow", "a red cow"] }

  let(:tool) do
    described_class.new(
      { prompts: prompts, seeds: [99, 32] },
      bot_user: bot_user,
      llm: llm,
      context: DiscourseAi::Personas::BotContext.new,
    )
  end

  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_35_turbo])
  end

  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{gpt_35_turbo.id}") }

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_35_turbo.name) }

  describe "#process" do
    it "can generate correct info" do
      _post = Fabricate(:post)

      SiteSetting.ai_stability_api_url = "https://api.stability.dev"
      SiteSetting.ai_stability_api_key = "abc"

      image =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

      artifacts = [{ base64: image, seed: 99 }]

      WebMock
        .stub_request(
          :post,
          "https://api.stability.dev/v1/generation/#{SiteSetting.ai_stability_engine}/text-to-image",
        )
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)
          expect(prompts).to include(json[:text_prompts][0][:text])
          true
        end
        .to_return(status: 200, body: { artifacts: artifacts }.to_json)

      info = tool.invoke(&progress_blk).to_json

      expect(JSON.parse(info)).to eq("prompts" => ["a pink cow", "a red cow"], "seeds" => [99, 99])
      expect(tool.custom_raw).to include("upload://")
      expect(tool.custom_raw).to include("[grid]")
      expect(tool.custom_raw).to include("a pink cow")
      expect(tool.custom_raw).to include("a red cow")
    end
  end
end
