# frozen_string_literal: true

RSpec.describe "AI Thumbnail Suggestions", type: :system do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:upload_1) do
    Fabricate(:image_upload, original_filename: "image1.png", width: 512, height: 512)
  end
  fab!(:upload_2) do
    Fabricate(:image_upload, original_filename: "image2.png", width: 512, height: 512)
  end
  fab!(:upload_3) do
    Fabricate(:image_upload, original_filename: "image3.png", width: 512, height: 512)
  end

  fab!(:post_illustrator_persona) do
    AiPersona.create!(
      name: "Post Illustrator",
      description: "Generates images for posts",
      system_prompt: "Generate images",
      enabled: true,
      created_by_id: user.id,
      allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
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
      created_by_id: user.id,
      enabled: true,
      is_image_generation_tool: true,
    )
  end

  before do
    enable_current_plugin
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true
    SiteSetting.ai_helper_enabled_features = "context_menu"
    SiteSetting.ai_helper_post_illustrator_persona = post_illustrator_persona.id
    post_illustrator_persona.update!(tools: [["custom-#{image_tool.id}", nil, true]])
    Jobs.run_immediately!
    sign_in(user)
  end

  let(:input) { "A description of an image that I want to generate" }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_helper_menu) { PageObjects::Components::AiComposerHelperMenu.new }
  let(:thumbnail_modal) { PageObjects::Modals::ThumbnailSuggestionsModal.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  def trigger_composer_helper(content)
    visit("/latest")
    page.find("#create-topic").click
    composer.fill_content(content)
    composer.click_toolbar_button("ai-helper-trigger")
  end

  def mock_thumbnail_generation
    allow_any_instance_of(DiscourseAi::Personas::Bot).to receive(:reply) do |_bot, _context, &block|
      custom_raw =
        "![#{upload_1.original_filename}](#{upload_1.short_url})\n" +
          "![#{upload_2.original_filename}](#{upload_2.short_url})\n" +
          "![#{upload_3.original_filename}](#{upload_3.short_url})"
      block.call("", custom_raw, :partial_invoke)
    end
  end

  context "when using illustrate post feature" do
    it "opens thumbnail modal when illustrate_post is selected" do
      mock_thumbnail_generation

      trigger_composer_helper(input)
      ai_helper_menu.select_helper_model("illustrate_post")

      expect(thumbnail_modal).to be_visible
      wait_for { thumbnail_modal.has_thumbnails? }
      expect(thumbnail_modal).to have_thumbnails
    end

    it "can select and save thumbnails" do
      mock_thumbnail_generation

      trigger_composer_helper(input)
      ai_helper_menu.select_helper_model("illustrate_post")

      wait_for { thumbnail_modal.has_thumbnails? }

      thumbnail_modal.select_thumbnail(0)
      thumbnail_modal.select_thumbnail(1)
      thumbnail_modal.click_save

      expected_markdown =
        "\n\n![#{upload_1.original_filename}|#{upload_1.width}x#{upload_1.height}](#{upload_1.short_url})\n![#{upload_2.original_filename}|#{upload_2.width}x#{upload_2.height}](#{upload_2.short_url})"

      wait_for { composer.composer_input.value.include?(expected_markdown) }
      expect(composer.composer_input.value).to include(expected_markdown)
    end

    it "save button is disabled with no selection" do
      mock_thumbnail_generation

      trigger_composer_helper(input)
      ai_helper_menu.select_helper_model("illustrate_post")

      wait_for { thumbnail_modal.has_thumbnails? }

      expect(thumbnail_modal.save_disabled?).to be true

      thumbnail_modal.select_thumbnail(0)
      expect(thumbnail_modal.save_disabled?).to be false
    end

    it "try again button regenerates thumbnails and clears selection" do
      mock_thumbnail_generation

      trigger_composer_helper(input)
      ai_helper_menu.select_helper_model("illustrate_post")

      wait_for { thumbnail_modal.has_thumbnails? }

      expect(thumbnail_modal.try_again_disabled?).to be false

      thumbnail_modal.select_thumbnail(0)
      thumbnail_modal.select_thumbnail(1)

      mock_thumbnail_generation

      thumbnail_modal.click_try_again

      wait_for { thumbnail_modal.loading? }
      wait_for { !thumbnail_modal.loading? }
      wait_for { thumbnail_modal.has_thumbnails? }

      expect(thumbnail_modal.save_disabled?).to be true
    end

    it "try again button is disabled while loading" do
      mock_thumbnail_generation

      trigger_composer_helper(input)
      ai_helper_menu.select_helper_model("illustrate_post")

      wait_for { thumbnail_modal.loading? }
      expect(thumbnail_modal.try_again_disabled?).to be true

      wait_for { !thumbnail_modal.loading? }
      expect(thumbnail_modal.try_again_disabled?).to be false
    end

    it "handles credit limit errors" do
      llm_model = LlmModel.find_by(id: SiteSetting.ai_default_llm_model)
      allocation = Fabricate(:llm_credit_allocation, llm_model: llm_model)
      exception =
        LlmCreditAllocation::CreditLimitExceeded.new(
          "AI credit limit reached",
          allocation: allocation,
        )

      allow(LlmCreditAllocation).to receive(:check_credits!).and_raise(exception)

      trigger_composer_helper(input)
      ai_helper_menu.select_helper_model("illustrate_post")

      expect(thumbnail_modal).to be_visible

      wait_for { toasts.has_error? }
    end
  end
end
