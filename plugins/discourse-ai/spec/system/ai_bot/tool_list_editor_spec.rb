# frozen_string_literal: true

describe "AI Tool List Editor Dropdown", type: :system do
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_enabled = true
    sign_in(admin)
  end

  it "shows main menu presets and can navigate to image generation category" do
    visit "/admin/plugins/discourse-ai/ai-tools"
    expect(page).to have_content("Tools")

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    expect(tool_menu).to have_css(".btn[data-option='browse_web_jina']")
    expect(tool_menu).to have_css(".btn[data-option='exchange_rate']")
    expect(tool_menu).to have_css(".btn[data-option='stock_quote']")
    expect(tool_menu).to have_css(".btn[data-option='image_generation_category']")
    expect(tool_menu).to have_css(".btn[data-option='empty_tool']")

    expect(page).not_to have_css(".ai-tool-preset-item[data-option='image_generation_openai']")

    tool_menu.option(".btn[data-option='image_generation_category']").click

    expect(page).to have_css(".ai-tool-preset-item[data-option='image_generation_openai']")
    expect(page).to have_css(".ai-tool-preset-item[data-option='image_generation_gemini']")
    expect(page).to have_css(".ai-tool-preset-item[data-option='image_generation_flux']")
    expect(page).to have_css(".btn[data-option='image_generation_custom']")

    expect(page).not_to have_css(".btn[data-option='browse_web_jina']")

    expect(page).to have_css(".btn-transparent .d-icon-chevron-left")
  end

  it "can navigate back from image generation category to main menu" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    tool_menu.option(".btn[data-option='image_generation_category']").click

    expect(page).to have_css(".ai-tool-preset-item[data-option='image_generation_openai']")

    find(".btn-transparent .d-icon-chevron-left").ancestor(".btn-transparent").click

    expect(page).to have_css(".btn[data-option='browse_web_jina']")
    expect(page).to have_css(".btn[data-option='exchange_rate']")
    expect(page).to have_css(".btn[data-option='image_generation_category']")

    expect(page).not_to have_css(".ai-tool-preset-item[data-option='image_generation_openai']")
  end

  it "navigates to new tool page when clicking image generation preset" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    tool_menu.option(".btn[data-option='image_generation_category']").click

    find(".ai-tool-preset-item[data-option='image_generation_openai']").click

    expect(page).to have_current_path(
      %r{/admin/plugins/discourse-ai/ai-tools/new\?presetId=image_generation_openai},
    )

    expect(page).to have_field("tool_name", with: "image_generation_openai")
    expect(page).to have_field("name", with: "GPT Image")
  end

  it "navigates to new tool page when clicking non-category preset" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    tool_menu.option(".btn[data-option='exchange_rate']").click

    expect(page).to have_current_path(
      %r{/admin/plugins/discourse-ai/ai-tools/new\?presetId=exchange_rate},
    )

    expect(page).to have_field("tool_name", with: "exchange_rate")
    expect(page).to have_field("name", with: "Exchange Rate")
  end

  it "displays image generation presets sorted by provider" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    tool_menu.option(".btn[data-option='image_generation_category']").click

    preset_items = page.all(".ai-tool-preset-item")

    provider_order = preset_items.map { |item| item.find(".ai-tool-preset-provider").text }

    expect(provider_order).to eq(provider_order.sort)
  end

  it "shows custom preset at the bottom separated by divider" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    tool_menu.option(".btn[data-option='image_generation_category']").click

    expect(page).to have_css(".btn[data-option='image_generation_custom']")

    dividers = page.all(".dropdown-menu__divider")
    expect(dividers.count).to eq(2)

    custom_preset_items = page.all(".btn[data-option='image_generation_custom']")
    expect(custom_preset_items.count).to eq(1)
  end

  it "resets menu state when closing dropdown" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    find(".ai-tool-list-editor__new-button").click
    tool_menu = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))

    tool_menu.option(".btn[data-option='image_generation_category']").click

    expect(page).to have_css(".ai-tool-preset-item[data-option='image_generation_openai']")

    page.find("body").click

    find(".ai-tool-list-editor__new-button").click

    expect(page).to have_css(".btn[data-option='browse_web_jina']")
    expect(page).not_to have_css(".ai-tool-preset-item[data-option='image_generation_openai']")
  end
end
