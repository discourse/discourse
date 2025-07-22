# frozen_string_literal: true

RSpec.describe "User AI preferences", type: :system, js: true do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:llm_model)
  let(:user_preferences_ai_page) { PageObjects::Pages::UserPreferencesAi.new }
  fab!(:discovery_persona) do
    Fabricate(:ai_persona, allowed_group_ids: [Group::AUTO_GROUPS[:admins]])
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_discover_persona = discovery_persona.id
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    assign_fake_provider_to(:ai_helper_model)
    assign_fake_provider_to(:ai_helper_image_caption_model)
    sign_in(user)
  end

  describe "automatic image caption setting" do
    context "when ai helper is disabled" do
      before { SiteSetting.ai_helper_enabled = false }

      it "should not have the setting present in the user preferences page" do
        user_preferences_ai_page.visit(user)
        expect(user_preferences_ai_page).to have_no_ai_preference("pref-auto-image-caption")
      end
    end

    context "when toggling the setting from the user preferences page" do
      before do
        SiteSetting.ai_helper_enabled = true
        SiteSetting.ai_helper_enabled_features = "image_caption"
        user.user_option.update!(auto_image_caption: false)
      end

      it "should update the preference to enabled" do
        user_preferences_ai_page.visit(user)
        user_preferences_ai_page.toggle_setting("pref-auto-image-caption")
        user_preferences_ai_page.save_changes
        wait_for(timeout: 5) { user.reload.user_option.auto_image_caption }
        expect(user.reload.user_option.auto_image_caption).to eq(true)
      end
    end
  end

  describe "search discoveries setting" do
    context "when discoveries are enabled" do
      before { SiteSetting.ai_bot_enabled = true }
      it "should have the setting present in the user preferences page" do
        user_preferences_ai_page.visit(user)
        expect(user_preferences_ai_page).to have_ai_preference("pref-ai-search-discoveries")
      end
    end

    context "when discoveries are disabled" do
      SiteSetting.ai_bot_enabled = false
      SiteSetting.ai_bot_discover_persona = nil

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
      expect(user_preferences_ai_page).to have_no_ai_preference("pref-auto-image-caption")
      expect(user_preferences_ai_page).to have_no_ai_preference("pref-ai-search-discoveries")
      expect(page).to have_content(I18n.t("js.discourse_ai.user_preferences.empty"))
    end
  end
end
