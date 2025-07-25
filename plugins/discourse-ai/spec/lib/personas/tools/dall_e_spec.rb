#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::DallE do
  let(:prompts) { ["a pink cow", "a red cow"] }

  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_35_turbo])
    SiteSetting.ai_openai_api_key = "abc"
  end

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_35_turbo.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{gpt_35_turbo.id}") }
  let(:progress_blk) { Proc.new {} }

  let(:dall_e) { described_class.new({ prompts: prompts }, llm: llm, bot_user: bot_user) }

  let(:base64_image) do
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  end

  describe "#process" do
    it "can generate tall images" do
      generator =
        described_class.new(
          { prompts: ["a cat"], aspect_ratio: "tall" },
          llm: llm,
          bot_user: bot_user,
        )

      data = [{ b64_json: base64_image, revised_prompt: "a tall cat" }]

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/images/generations")
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)

          expect(json[:prompt]).to eq("a cat")
          expect(json[:size]).to eq("1024x1792")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = generator.invoke(&progress_blk).to_json
      expect(JSON.parse(info)).to eq("prompts" => ["a tall cat"])
    end

    it "can generate correct info with azure" do
      _post = Fabricate(:post)

      SiteSetting.ai_openai_image_generation_url = "https://test.azure.com/some_url"

      data = [{ b64_json: base64_image, revised_prompt: "a pink cow 1" }]

      WebMock
        .stub_request(:post, SiteSetting.ai_openai_image_generation_url)
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)

          expect(prompts).to include(json[:prompt])
          expect(request.headers["Api-Key"]).to eq("abc")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = dall_e.invoke(&progress_blk).to_json

      expect(JSON.parse(info)).to eq("prompts" => ["a pink cow 1", "a pink cow 1"])
      expect(dall_e.custom_raw).to include("upload://")
      expect(dall_e.custom_raw).to include("[grid]")
      expect(dall_e.custom_raw).to include("a pink cow 1")
    end

    it "can generate correct info" do
      data = [{ b64_json: base64_image, revised_prompt: "a pink cow 1" }]

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/images/generations")
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)
          expect(prompts).to include(json[:prompt])
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = dall_e.invoke(&progress_blk).to_json

      expect(JSON.parse(info)).to eq("prompts" => ["a pink cow 1", "a pink cow 1"])
      expect(dall_e.custom_raw).to include("upload://")
      expect(dall_e.custom_raw).to include("[grid]")
      expect(dall_e.custom_raw).to include("a pink cow 1")
    end
  end
end
