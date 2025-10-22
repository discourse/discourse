# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::CreateImage do
  let(:prompts) { ["a watercolor painting", "an abstract design"] }

  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_35_turbo])
    SiteSetting.ai_openai_api_key = "abc"
  end

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_35_turbo.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(gpt_35_turbo) }
  let(:progress_blk) { Proc.new {} }

  let(:create_image) { described_class.new({ prompts: prompts }, llm: llm, bot_user: bot_user) }

  let(:base64_image) do
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  end

  describe "#process" do
    it "can reject generation of images and return a proper error to llm" do
      error_message = {
        error: {
          message:
            "Your request was rejected as a result of our safety system. Your request may contain content that is not allowed by our safety system.",
          type: "user_error",
          param: nil,
          code: "moderation_blocked",
        },
      }

      WebMock.stub_request(:post, "https://api.openai.com/v1/images/generations").to_return(
        status: 400,
        body: error_message.to_json,
      )

      info = create_image.invoke(&progress_blk).to_json
      expect(info).to include("Your request was rejected as a result of our safety system.")
      expect(create_image.chain_next_response?).to eq(true)
    end
    it "can generate images with gpt-image-1 model" do
      data = [{ b64_json: base64_image, revised_prompt: "a watercolor painting of flowers" }]

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/images/generations")
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)

          expect(prompts).to include(json[:prompt])
          expect(json[:model]).to eq("gpt-image-1")
          expect(json[:size]).to eq("auto")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = create_image.invoke(&progress_blk).to_json

      expect(JSON.parse(info)).to eq(
        {
          "prompts" => [
            {
              "prompt" => "a watercolor painting of flowers",
              "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
            },
            {
              "prompt" => "a watercolor painting of flowers",
              "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
            },
          ],
        },
      )
      expect(create_image.custom_raw).to include("upload://")
      expect(create_image.custom_raw).to include("[grid]")
      expect(create_image.custom_raw).to include("a watercolor painting of flowers")
    end

    it "can defaults to auto size" do
      create_image_with_size =
        described_class.new({ prompts: ["a landscape"] }, llm: llm, bot_user: bot_user)

      data = [{ b64_json: base64_image, revised_prompt: "a detailed landscape" }]

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/images/generations")
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)

          expect(json[:prompt]).to eq("a landscape")
          expect(json[:size]).to eq("auto")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = create_image_with_size.invoke(&progress_blk).to_json
      expect(JSON.parse(info)).to eq(
        "prompts" => [
          {
            "prompt" => "a detailed landscape",
            "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
          },
        ],
      )
    end

    it "handles custom API endpoint" do
      SiteSetting.ai_openai_image_generation_url = "https://custom-api.example.com/images/generate"

      data = [{ b64_json: base64_image, revised_prompt: "a watercolor painting" }]

      WebMock
        .stub_request(:post, SiteSetting.ai_openai_image_generation_url)
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)
          expect(prompts).to include(json[:prompt])
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = create_image.invoke(&progress_blk).to_json
      expect(JSON.parse(info)).to eq(
        "prompts" => [
          {
            "prompt" => "a watercolor painting",
            "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
          },
          {
            "prompt" => "a watercolor painting",
            "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
          },
        ],
      )
    end
  end
end
