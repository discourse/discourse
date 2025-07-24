# frozen_string_literal: true

RSpec.describe "AI Spam Configuration", type: :system do
  fab!(:admin)
  let(:llm_model) { Fabricate(:llm_model) }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "can properly configure spam settings" do
    visit "/admin/plugins/discourse-ai/ai-spam"

    expect(page).to have_css(".ai-spam__llm-placeholder")

    toggle = PageObjects::Components::DToggleSwitch.new(".ai-spam__toggle")

    toggle.toggle
    dialog = PageObjects::Components::Dialog.new
    expect(dialog).to have_content(I18n.t("discourse_ai.llm.configuration.must_select_model"))
    dialog.click_ok

    expect(toggle.unchecked?).to eq(true)

    llm_model
    visit "/admin/plugins/discourse-ai/ai-spam"

    toggle = PageObjects::Components::DToggleSwitch.new(".ai-spam__toggle")
    toggle.toggle

    try_until_success { expect(AiModerationSetting.spam&.llm_model_id).to eq(llm_model.id) }

    find(".ai-spam__instructions-input").fill_in(with: "Test spam detection instructions")
    find(".ai-spam__instructions-save").click

    toasts = PageObjects::Components::Toasts.new
    expect(toasts).to have_content(I18n.t("js.discourse_ai.spam.settings_saved"))

    expect(AiModerationSetting.spam.custom_instructions).to eq("Test spam detection instructions")

    visit "/admin/plugins/discourse-ai/ai-llms"

    expect(find(".ai-llm-list-editor__usages")).to have_content(
      I18n.t("js.discourse_ai.llms.usage.ai_spam"),
    )
  end
end
