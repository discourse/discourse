# frozen_string_literal: true

RSpec.describe "Saving illustrated post images" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:category)
  let(:composer) { PageObjects::Components::Composer.new }
  let(:menu) { PageObjects::Components::AiComposerHelperMenu.new }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true
    Fabricate(
      :ai_tool,
      parameters: [{ name: "prompt", type: "string", description: "Prompt" }],
      script: "function invoke() { upload.create(); chain.setCustomRaw(); }",
    )
    DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
    sign_in(admin)
  end

  it "appends the selected illustration in the Markdown composer" do
    save_illustration(rich_text: false)
  end

  it "appends the selected illustration in the rich text composer" do
    save_illustration(rich_text: true)
  end

  def save_illustration(rich_text:)
    upload =
      UploadCreator.new(file_from_fixtures("logo.png"), "illustration.png").create_for(admin.id)
    thumbnails = [
      {
        id: upload.id,
        original_filename: upload.original_filename,
        width: upload.width,
        height: upload.height,
        short_url: upload.short_url,
        url: upload.url,
        thumbnail_width: 100,
        thumbnail_height: 100,
      },
    ]
    DiscourseAi::AiHelper::GenerateThumbnails.stubs(:call).returns(
      stub(:failure? => false, :[] => thumbnails),
    )

    visit "/new-topic"
    if rich_text
      composer.toggle_rich_editor
      expect(composer).to have_rich_editor_active
      composer.focus
      composer.type_content("A happy dog in a park.")
    else
      composer.fill_content("A happy dog in a park.")
    end
    composer.click_toolbar_button("ai-helper-trigger")
    menu.select_helper_model("illustrate_post")
    find(".ai-thumbnail-suggestions__item button").click
    find(".thumbnail-suggestions-modal .create").click

    expect(page).to have_no_css(".thumbnail-suggestions-modal")
    if rich_text
      expect(composer.rich_editor).to have_css("img")
      expect(composer.rich_editor).to have_text("A happy dog in a park.")
      composer.toggle_rich_editor
    end
    expect(composer.composer_input.value).to include("A happy dog in a park.", upload.short_url)
  end
end
