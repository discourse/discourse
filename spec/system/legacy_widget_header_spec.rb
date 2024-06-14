# frozen_string_literal: true

RSpec.describe "Legacy Widget Header", type: :system do
  before { SiteSetting.glimmer_header_mode = "disabled" }

  context "when resetting password" do
    fab!(:current_user) { Fabricate(:user) }

    it "does not show search, login, or signup buttons" do
      email_token =
        current_user.email_tokens.create!(
          email: current_user.email,
          scope: EmailToken.scopes[:password_reset],
        )

      visit "/u/password-reset/#{email_token.token}"
      expect(page).not_to have_css("button.login-button")
      expect(page).not_to have_css("button.sign-up-button")
      expect(page).not_to have_css(".search-dropdown #search-button")
    end
  end
end
