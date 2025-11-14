# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::GenerateThumbnails do
  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:user)
    fab!(:admin)
    fab!(:post_illustrator_persona) do
      AiPersona.create!(
        id: -21,
        name: "Post Illustrator",
        description: "Generates images for posts",
        system_prompt: "Generate images",
        enabled: true,
        created_by_id: admin.id,
      )
    end
    fab!(:image_tool) do
      AiTool.create!(
        name: "image_generation_test",
        tool_name: "image_generation_test",
        description: "Test image generation",
        summary: "Test",
        parameters: [{ name: "prompt", type: "string", required: true }],
        script: <<~JS,
          function invoke(params) {
            const image = upload.create("test.png", "base64data");
            chain.setCustomRaw("![test](upload://test123)");
            return { result: "success" };
          }
        JS
        created_by_id: admin.id,
        enabled: true,
        is_image_generation_tool: true,
      )
    end
    fab!(:upload) do
      Fabricate(
        :upload,
        sha1: Upload.generate_digest_from_short_url("upload://test123"),
        original_filename: "test.png",
      )
    end

    let(:params) { { params: { text: } } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:text) { "A beautiful sunset over the ocean" }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_helper_post_illustrator_persona = post_illustrator_persona.id

      # Configure PostIllustrator persona with the image tool
      post_illustrator_persona.update!(
        tools: [["custom-#{image_tool.id}", nil, true]],
        force_tool_use: [["custom-#{image_tool.id}", nil, true]],
      )
    end

    context "when text parameter is missing" do
      let(:text) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when text parameter exceeds maximum length" do
      let(:text) { "a" * 10_001 }

      it { is_expected.to fail_a_contract }
    end

    context "when persona is not found" do
      before { SiteSetting.ai_helper_post_illustrator_persona = 99_999 }

      it { is_expected.to fail_to_find_a_model(:persona) }
    end

    context "when persona has no image generation tool" do
      before do
        # Remove tools from persona
        post_illustrator_persona.update!(tools: [], force_tool_use: [])
      end

      it { is_expected.to fail_a_policy(:has_image_generation_tool) }
    end

    context "when image generation succeeds" do
      before do
        # Mock the bot reply to return custom_raw with upload URL
        allow_any_instance_of(DiscourseAi::Personas::Bot).to receive(
          :reply,
        ) do |_bot, _context, &block|
          block.call("", "![test](#{upload.short_url})", :partial_invoke)
        end
      end

      it { is_expected.to run_successfully }

      it "generates and returns thumbnails" do
        expect(result[:thumbnails]).to be_present
        expect(result[:thumbnails].length).to eq(1)
        expect(result[:thumbnails].first[:id]).to eq(upload.id)
        expect(result[:thumbnails].first[:short_url]).to eq(upload.short_url)
      end
    end

    context "when bot returns no custom_raw" do
      before do
        allow_any_instance_of(DiscourseAi::Personas::Bot).to receive(:reply).and_return(nil)
      end

      it { is_expected.to fail_a_step(:generate_images) }
    end

    context "when bot returns custom_raw without upload URLs" do
      before do
        allow_any_instance_of(DiscourseAi::Personas::Bot).to receive(
          :reply,
        ) do |_bot, _context, &block|
          block.call("Some text without uploads", nil, :custom_raw)
        end
      end

      it { is_expected.to fail_a_step(:parse_uploads) }
    end

    context "when upload is not found" do
      before do
        allow_any_instance_of(DiscourseAi::Personas::Bot).to receive(
          :reply,
        ) do |_bot, _context, &block|
          block.call("", "![test](upload://nonexistentsha1234567890123456789012)", :partial_invoke)
        end
      end

      it "returns empty thumbnails array" do
        expect(result).to run_successfully
        expect(result[:thumbnails]).to eq([])
      end
    end
  end
end
