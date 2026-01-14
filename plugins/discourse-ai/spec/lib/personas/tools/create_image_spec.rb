# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::CreateImage do
  let(:prompts) { ["a watercolor painting", "an abstract design"] }

  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }
  fab!(:admin)

  fab!(:test_upload) do
    Fabricate(
      :upload,
      sha1: Upload.sha1_from_short_url("upload://test123"),
      original_filename: "test_image.png",
    )
  end

  fab!(:image_tool) do
    AiTool.create!(
      name: "test_image_generator",
      tool_name: "test_image_generator",
      description: "Test image generation tool",
      summary: "Generates test images",
      parameters: [{ name: "prompt", type: "string", required: true }],
      script: <<~JS,
        function invoke(params) {
          upload.create("test_image.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");
          chain.setCustomRaw(`![${params.prompt}](upload://test123)`);
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

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_35_turbo.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(gpt_35_turbo) }
  let(:progress_blk) { Proc.new {} }

  let(:create_image) { described_class.new({ prompts: prompts }, llm: llm, bot_user: bot_user) }

  describe "#invoke" do
    it "returns error when no image generation tools are configured" do
      image_tool.update!(enabled: false)

      result = create_image.invoke(&progress_blk)

      expect(result[:error]).to include("No image generation tools configured")
      expect(create_image.chain_next_response?).to eq(true)
    end

    it "delegates to available custom image generation tool" do
      result = create_image.invoke(&progress_blk)

      expect(result[:prompts]).to be_an(Array)
      expect(result[:prompts].length).to eq(2)
      expect(result[:prompts].first[:prompt]).to eq("a watercolor painting")
      expect(result[:prompts].first[:url]).to include("upload://")
      expect(create_image.custom_raw).to include("[grid]")
      expect(create_image.custom_raw).to include("upload://")
    end

    it "limits to 4 prompts maximum" do
      many_prompts = ["prompt 1", "prompt 2", "prompt 3", "prompt 4", "prompt 5", "prompt 6"]
      create_image_many =
        described_class.new({ prompts: many_prompts }, llm: llm, bot_user: bot_user)

      result = create_image_many.invoke(&progress_blk)

      expect(result[:prompts].length).to eq(4)
    end

    it "handles errors from custom tools gracefully" do
      # Create a tool that raises an error
      failing_tool =
        AiTool.create!(
          name: "failing_tool",
          tool_name: "failing_tool",
          description: "A tool that fails",
          summary: "Fails",
          parameters: [{ name: "prompt", type: "string", required: true }],
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

      result = create_image.invoke(&progress_blk)

      expect(result[:error]).to be_present
      expect(create_image.chain_next_response?).to eq(true)
    end
  end
end
