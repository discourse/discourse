# frozen_string_literal: true

RSpec.describe "User AI preferences", type: :system do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:llm_model)
  let(:user_preferences_ai_page) { PageObjects::Pages::UserPreferencesAi.new }
  fab!(:discovery_persona) do
    Fabricate(:ai_persona, allowed_group_ids: [Group::AUTO_GROUPS[:admins]])
  end

  before do
    enable_current_plugin
    SiteSetting.ai_discover_persona = discovery_persona.id
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    assign_fake_provider_to(:ai_default_llm_model)
    sign_in(user)
  end

  describe "search discoveries setting" do
    context "when discoveries are enabled" do
      before { SiteSetting.ai_discover_enabled = true }

      it "should have the setting present in the user preferences page" do
        user_preferences_ai_page.visit(user)
        expect(user_preferences_ai_page).to have_ai_preference("pref-ai-search-discoveries")
      end

      context "when the user can't use personas" do
        it "doesn't render the option in the preferences page" do
          Group.find_by(id: Group::AUTO_GROUPS[:admins]).remove(user)

          user_preferences_ai_page.visit(user)
          expect(user_preferences_ai_page).to have_no_ai_preference("pref-ai-search-discoveries")
        end
      end
    end

    context "when discoveries are disabled" do
      SiteSetting.ai_discover_enabled = false

      it "should not have the setting present in the user preferences page" do
        user_preferences_ai_page.visit(user)
        expect(user_preferences_ai_page).to have_no_ai_preference("pref-ai-search-discoveries")
      end
    end
  end

  describe "when no settings are available" do
    before do
      SiteSetting.ai_helper_enabled = false
      SiteSetting.ai_bot_enabled = false
    end

    it "should not have any AI preferences and should show a message" do
      user_preferences_ai_page.visit(user)
      expect(user_preferences_ai_page).to have_no_ai_preference("pref-ai-search-discoveries")
      expect(page).to have_content(I18n.t("js.discourse_ai.user_preferences.empty"))
    end
  end
end
