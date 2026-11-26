# frozen_string_literal: true

describe "Viewing another user's AI preferences" do
  fab!(:admin)
  fab!(:eligible_user, :user)
  fab!(:group) { Fabricate(:group, users: [eligible_user]) }
  fab!(:llm_model)
  fab!(:agent) { Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id) }

  let(:user_preferences_ai_page) { PageObjects::Pages::UserPreferencesAi.new }

  before do
    enable_current_plugin
    enable_legacy_discover
    SiteSetting.ai_discover_agent = agent.id
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_agent = agent.id
    SiteSetting.ai_ask_ai_allowed_groups = group.id.to_s
    sign_in(admin)
  end

  it "shows and saves the AI preferences of an eligible user" do
    user_preferences_ai_page.visit(eligible_user)
    user_preferences_ai_page.toggle_setting("pref-ai-ask-ai-default")
    user_preferences_ai_page.toggle_setting("pref-ai-search-discoveries")
    user_preferences_ai_page.save_changes

    expect(page).to have_content(I18n.t("js.saved"))

    page.refresh

    expect(user_preferences_ai_page).not_to have_ai_preference_checked("pref-ai-ask-ai-default")
    expect(user_preferences_ai_page).not_to have_ai_preference_checked("pref-ai-search-discoveries")
  end
end
