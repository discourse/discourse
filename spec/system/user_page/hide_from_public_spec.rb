# frozen_string_literal: true

describe "hide_user_profiles_from_public", type: :system do
  let(:user) { Fabricate(:user) }
  before { SiteSetting.hide_user_profiles_from_public = true }

  it "displays an error when navigating straight to a profile" do
    visit("/u/#{user.username}")
    expect(page).to have_css(".error-page .reason", text: I18n.t("js.errors.reasons.forbidden"))
    expect(page).to have_css(".error-page .desc", text: I18n.t("js.user.login_to_view_profile"))
  end

  it "displays an error when navigating from an internal link" do
    post =
      Fabricate(
        :post,
        user: user,
        raw: "Check out my profile at [#{user.username}](/u/#{user.username})",
      )
    visit(post.url)
    find(".cooked a[href='/u/#{user.username}']").click

    expect(page).to have_css(".error-page .reason", text: I18n.t("js.errors.reasons.forbidden"))
    expect(page).to have_css(".error-page .desc", text: I18n.t("js.user.login_to_view_profile"))
    expect(page).to have_current_path("/u/#{user.username}")

    find(".error-page .buttons .btn-primary", text: "Back").click
    expect(page).to have_current_path(post.url)
  end
end
