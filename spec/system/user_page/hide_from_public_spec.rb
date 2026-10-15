# frozen_string_literal: true

describe "hide_user_profiles_from_public" do
  let(:user) { Fabricate(:user) }

  before { SiteSetting.hide_user_profiles_from_public = true }

  it "displays an error when navigating straight to a profile" do
    browser_page.goto("/u/#{user.username}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".error-page .reason").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.errors.reasons.forbidden"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".error-page .desc").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.login_to_view_profile"))],
      useInnerText: true,
    )
  end

  it "displays an error when navigating from an internal link" do
    post =
      Fabricate(
        :post,
        user: user,
        raw: "Check out my profile at [#{user.username}](/u/#{user.username})",
      )
    browser_page.goto(post.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".cooked a[href='/u/#{user.username}']").filter(visible: true).click

    expect(
      browser_root.locator(".error-page .reason").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.errors.reasons.forbidden"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".error-page .desc").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.login_to_view_profile"))],
      useInnerText: true,
    )
    expect(browser_page).to PlaywrightMatchers.have_url("/u/#{user.username}")

    browser_root
      .locator(".error-page .buttons .btn-primary")
      .filter(visible: true)
      .filter(hasText: browser_text_pattern("Back"))
      .click
    expect(browser_page).to PlaywrightMatchers.have_url(
      Regexp.new(
        "^(?:#{Regexp.escape(post.url)}|https?://[^/]+#{Regexp.escape(post.topic.relative_url)})$",
      ),
    )
  end
end
