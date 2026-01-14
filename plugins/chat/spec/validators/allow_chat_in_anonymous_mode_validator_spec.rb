# frozen_string_literal: true

RSpec.describe Chat::AllowChatInAnonymousModeValidator do
  context "when anonymous mode is disabled" do
    before { SiteSetting.allow_anonymous_mode = false }

    it "does not allow the allow_chat_in_anonymous_mode setting to be enabled" do
      expect { SiteSetting.allow_chat_in_anonymous_mode = true }.to raise_error(
        Discourse::InvalidParameters,
        "allow_chat_in_anonymous_mode: #{I18n.t("site_settings.errors.allow_chat_in_anonymous_mode_invalid")}",
      )
    end

    it "allows the setting to be disabled" do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.allow_chat_in_anonymous_mode = true

      SiteSetting.allow_anonymous_mode = false
      expect { SiteSetting.allow_likes_in_anonymous_mode = false }.not_to raise_error
    end
  end

  context "when anonymous mode is enabled" do
    before { SiteSetting.allow_anonymous_mode = true }

    it "allows the setting to be enabled" do
      expect { SiteSetting.allow_likes_in_anonymous_mode = true }.not_to raise_error
    end
  end
end
