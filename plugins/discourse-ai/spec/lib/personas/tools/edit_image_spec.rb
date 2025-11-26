# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::EditImage do
  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }
  fab!(:admin)
  fab!(:user)

  fab!(:edited_upload) do
    Fabricate(
      :upload,
      sha1: Upload.sha1_from_short_url("upload://edited456"),
      original_filename: "edited_image.png",
    )
  end

  fab!(:image_tool) do
    AiTool.create!(
      name: "test_image_editor",
      tool_name: "test_image_editor",
      description: "Test image editing tool",
      summary: "Edits test images",
      parameters: [
        { name: "prompt", type: "string", required: true },
        { name: "image_urls", type: "array", item_type: "string", required: true },
      ],
      script: <<~JS,
        function invoke(params) {
          upload.create("edited_image.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");
          chain.setCustomRaw(`![${params.prompt}](upload://edited456)`);
          return { result: "success" };
        }
      JS
      created_by_id: admin.id,
      enabled: true,
      is_image_generation_tool: true,
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_35_turbo])
  end

  let(:image_upload) do
    UploadCreator.new(
      File.open(Rails.root.join("spec/fixtures/images/smallest.png")),
      "smallest.png",
    ).create_for(user.id)
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
      context: DiscourseAi::Personas::BotContext.new(user: user),
    )
  end

  describe "#invoke" do
    it "returns error when no image generation tools are configured" do
      image_tool.update!(enabled: false)

      result = edit_image.invoke(&progress_blk)

      expect(result[:error]).to include("No image generation tools configured")
      expect(edit_image.chain_next_response?).to eq(true)
    end

    it "returns error when no valid images provided" do
      edit_image_no_images =
        described_class.new(
          { image_urls: [], prompt: prompt },
          llm: llm,
          bot_user: bot_user,
          context: DiscourseAi::Personas::BotContext.new(user: user),
        )

      result = edit_image_no_images.invoke(&progress_blk)

      expect(result[:error]).to include("No valid images provided")
      expect(edit_image_no_images.chain_next_response?).to eq(true)
    end

    it "delegates to available custom image editing tool" do
      result = edit_image.invoke(&progress_blk)

      expect(result[:prompt]).to eq(prompt)
      expect(result[:url]).to include("upload://")
      expect(edit_image.custom_raw).to include("upload://")
      expect(edit_image.custom_raw).to include("![")
    end

    it "checks Guardian permissions for uploads from private posts" do
      # Create a private message post with an upload
      private_topic = Fabricate(:private_message_topic, user: admin)
      private_post = Fabricate(:post, topic: private_topic, user: admin)

      # Create an upload associated with the private post
      private_upload =
        UploadCreator.new(
          File.open(Rails.root.join("spec/fixtures/images/smallest.png")),
          "private.png",
        ).create_for(admin.id)
      private_upload.update!(access_control_post_id: private_post.id)

      # Try to edit the private upload as a different user who doesn't have access
      edit_private_image =
        described_class.new(
          { image_urls: [private_upload.short_url], prompt: prompt },
          llm: llm,
          bot_user: bot_user,
          context: DiscourseAi::Personas::BotContext.new(user: user),
        )

      result = edit_private_image.invoke(&progress_blk)

      expect(result[:error]).to include("Access denied")
      expect(edit_private_image.chain_next_response?).to eq(true)
    end

    it "allows editing uploads from private posts if user has access" do
      # Create a private message post with an upload
      private_topic = Fabricate(:private_message_topic, user: user)
      private_post = Fabricate(:post, topic: private_topic, user: user)

      # Create an upload associated with the private post
      private_upload =
        UploadCreator.new(
          File.open(Rails.root.join("spec/fixtures/images/smallest.png")),
          "private.png",
        ).create_for(user.id)
      private_upload.update!(access_control_post_id: private_post.id)

      # Try to edit the private upload as the same user who has access
      edit_private_image =
        described_class.new(
          { image_urls: [private_upload.short_url], prompt: prompt },
          llm: llm,
          bot_user: bot_user,
          context: DiscourseAi::Personas::BotContext.new(user: user),
        )

      result = edit_private_image.invoke(&progress_blk)

      # Should succeed since user has access
      expect(result[:error]).to be_nil
      expect(result[:url]).to include("upload://")
    end

    it "handles errors from custom tools gracefully" do
      # Create a tool that raises an error
      failing_tool =
        AiTool.create!(
          name: "failing_edit_tool",
          tool_name: "failing_edit_tool",
          description: "A tool that fails",
          summary: "Fails",
          parameters: [
            { name: "prompt", type: "string", required: true },
            { name: "image_urls", type: "array", item_type: "string", required: true },
          ],
          script: <<~JS,
            function invoke(params) {
              throw new Error("Tool error");
            }
          JS
          created_by_id: admin.id,
          enabled: true,
          is_image_generation_tool: true,
        )

      # Disable the working tool so the failing one is used
      image_tool.update!(enabled: false)

      result = edit_image.invoke(&progress_blk)

      expect(result[:error]).to be_present
      expect(edit_image.chain_next_response?).to eq(true)
    end
  end
end
