# frozen_string_literal: true

RSpec.describe "Amazon Associated Account Preferences", type: :system do
  fab!(:user)

  let!(:user_account_preferences_page) { PageObjects::Pages::UserPreferencesAccount.new }

  before do
    SiteSetting.login_with_amazon_client_id = "somekey"
    SiteSetting.login_with_amazon_client_secret = "somesecretkey"
    enable_current_plugin
  end

  describe "with user connect enabled" do
    before { SiteSetting.login_with_amazon_user_can_connect = true }

    it "shows the connect button" do
      sign_in(user)
      user_account_preferences_page.visit(user)
      expect(page).to have_css(".associated-accounts .amazon")
      expect(page).to have_css(".associated-accounts .amazon .associated-account__actions button")
      expect(find(".associated-accounts .amazon .associated-account__actions button")).to have_text(
        I18n.t("js.user.associated_accounts.connect"),
      )
    end
  end

  describe "with user connect disabled" do
    before { SiteSetting.login_with_amazon_user_can_connect = false }

    it "does not show the connect button" do
      sign_in(user)
      user_account_preferences_page.visit(user)
      expect(page).not_to have_css(".associated-accounts .amazon")
    end
  end

  describe "with already associated account" do
    fab!(:user_associated_account) do
      UserAssociatedAccount.create!(provider_name: "amazon", provider_uid: "1234", user_id: user.id)
    end

    describe "with user revoke enabled" do
      before { SiteSetting.login_with_amazon_user_can_revoke = true }
      it "shows the revoke button" do
        sign_in(user)
        user_account_preferences_page.visit(user)
        expect(page).to have_css(".associated-accounts .amazon")
        expect(page).to have_css(".associated-accounts .amazon .associated-account__actions button")
        expect(page).to have_css(
          ".associated-accounts .amazon .associated-account__actions button svg.d-icon-trash-can",
        )
      end
    end

    describe "with user revoke disabled" do
      before { SiteSetting.login_with_amazon_user_can_revoke = false }
      it "shows the revoke button" do
        sign_in(user)
        user_account_preferences_page.visit(user)
        expect(page).to have_css(".associated-accounts .amazon")
        expect(page).not_to have_css(
          ".associated-accounts .amazon .associated-account__actions button",
        )
      end
    end
  end
end
