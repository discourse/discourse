# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::EditImage do
  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_35_turbo])
    SiteSetting.ai_openai_api_key = "abc"
  end

  let(:image_upload) do
    UploadCreator.new(
      File.open(Rails.root.join("spec/fixtures/images/smallest.png")),
      "smallest.png",
    ).create_for(Discourse.system_user.id)
  end

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_35_turbo.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(gpt_35_turbo) }
  let(:progress_blk) { Proc.new {} }

  let(:prompt) { "add a rainbow in the background" }

  let(:edit_image) do
    described_class.new(
      { image_urls: [image_upload.short_url], prompt: prompt },
      llm: llm,
      bot_user: bot_user,
    )
  end

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

      WebMock.stub_request(:post, "https://api.openai.com/v1/images/edits").to_return(
        status: 400,
        body: error_message.to_json,
      )

      info = edit_image.invoke(&progress_blk).to_json
      expect(info).to include("Your request was rejected as a result of our safety system.")
      expect(edit_image.chain_next_response?).to eq(true)
    end

    it "can edit an image with the GPT image model" do
      data = [{ b64_json: base64_image, revised_prompt: "image with rainbow added in background" }]

      # Stub the OpenAI API call
      WebMock
        .stub_request(:post, "https://api.openai.com/v1/images/edits")
        .with do |request|
          # The request is multipart/form-data, so we can't easily parse the body
          # Just check that the request was made to the right endpoint
          expect(request.headers["Content-Type"]).to include("multipart/form-data")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = edit_image.invoke(&progress_blk).to_json

      expect(JSON.parse(info)).to eq(
        {
          "prompt" => "image with rainbow added in background",
          "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
        },
      )
      expect(edit_image.custom_raw).to include("upload://")
      expect(edit_image.custom_raw).to include("![image with rainbow added in background]")
    end

    it "handles custom API endpoint" do
      SiteSetting.ai_openai_image_edit_url = "https://custom-api.example.com/images/edit"

      data = [{ b64_json: base64_image, revised_prompt: "image with rainbow added" }]

      # Stub the custom API endpoint
      WebMock
        .stub_request(:post, SiteSetting.ai_openai_image_edit_url)
        .with do |request|
          expect(request.headers["Content-Type"]).to include("multipart/form-data")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      info = edit_image.invoke(&progress_blk).to_json

      expect(JSON.parse(info)).to eq(
        {
          "prompt" => "image with rainbow added",
          "url" => "upload://pv9zsrM93Jz3U8xELTJCPYU2DD0.png",
        },
      )
    end
  end
end
