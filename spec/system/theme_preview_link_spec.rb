# frozen_string_literal: true

describe "Theme preview links" do
  fab!(:admin)
  fab!(:theme)

  before { sign_in(admin) }

  it "previews the theme when the link is followed inside the app" do
    visit("/latest")
    expect(page).to have_css("#main-outlet")
    expect(page).to have_no_css(
      "meta[name='discourse_theme_id'][content='#{theme.id}']",
      visible: false,
    )

    # a preview link in a post or chat message, which the app would otherwise
    # follow without loading the page again
    page.execute_script(<<~JS)
      const link = document.createElement("a");
      link.href = "/?preview_theme_id=#{theme.id}";
      link.className = "test-preview-link";
      link.textContent = "Preview";
      document.querySelector("#main-outlet").prepend(link);
    JS
    find(".test-preview-link").click

    expect(page).to have_css(
      "meta[name='discourse_theme_id'][content='#{theme.id}']",
      visible: false,
    )
    expect(page).to have_css("#global-notice-theme-preview")
    expect(page).to have_no_css("#global-notice-theme-preview-failed")
  end
end
