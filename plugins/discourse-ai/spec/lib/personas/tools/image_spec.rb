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
  fab!(:admin)

  fab!(:test_upload1) do
    Fabricate(
      :upload,
      sha1: Upload.sha1_from_short_url("upload://test123"),
      original_filename: "test_image1.png",
    )
  end

  fab!(:test_upload2) do
    Fabricate(
      :upload,
      sha1: Upload.sha1_from_short_url("upload://test456"),
      original_filename: "test_image2.png",
    )
  end

  fab!(:image_tool) do
    AiTool.create!(
      name: "test_image_generator",
      tool_name: "test_image_generator",
      description: "Test image generation tool",
      summary: "Generates test images",
      parameters: [
        { name: "prompt", type: "string", required: true },
        { name: "seeds", type: "array", item_type: "integer", required: false },
      ],
      script: <<~JS,
        function invoke(params) {
          // Create images for each seed
          const seeds = params.seeds || [99];
          const imageUrls = ["upload://test123", "upload://test456"];

          upload.create("test_image1.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");
          upload.create("test_image2.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");

          chain.setCustomRaw(`![${params.prompt}](${imageUrls[0]}) ![${params.prompt}](${imageUrls[1]})`);
          return { seed: 99 };
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

  let(:llm) { DiscourseAi::Completions::Llm.proxy(gpt_35_turbo) }

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_35_turbo.name) }

  describe "#process" do
    it "can generate correct info" do
      info = tool.invoke(&progress_blk).to_json

      # Custom tools don't provide seeds, so they will be nil
      expect(JSON.parse(info)).to eq(
        "prompts" => ["a pink cow", "a red cow"],
        "seeds" => [nil, nil],
      )
      expect(tool.custom_raw).to include("upload://")
      expect(tool.custom_raw).to include("[grid]")
      expect(tool.custom_raw).to include("a pink cow")
      expect(tool.custom_raw).to include("a red cow")
    end
  end
end
