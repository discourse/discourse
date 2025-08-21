# frozen_string_literal: true

describe "Impersonation", type: :system do
  fab!(:admin)
  fab!(:user)

  before do
    SiteSetting.experimental_impersonation = true

    sign_in(admin)
  end

  it "allows you to start and stop impersonating with the click of a button" do
    visit("/admin/users/#{user.id}/#{user.username}")

    page.find(".btn-impersonate").click

    expect(page).to have_current_path("/")
    expect(page).to have_css(
      ".impersonation-notice",
      text: I18n.t("js.impersonation.notice", username: user.username),
    )

    visit("/latest")

    page.find(".impersonation-notice .btn-danger").click

    expect(page).to have_current_path("/")
    expect(page).to have_no_css(".impersonation-notice")
  end
end
