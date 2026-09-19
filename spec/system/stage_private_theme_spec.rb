# frozen_string_literal: true

RSpec.describe "Stage a private theme" do
  fab!(:admin)

  let(:themes_page) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:theme_page) { PageObjects::Pages::AdminCustomizeThemes.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:repository_url) { "git@github.com:discourse/private-theme.git" }

  before { sign_in(admin) }

  it "lets an admin stage a private theme before repository access is granted" do
    themes_page.visit
    install_modal = themes_page.click_install_button
    install_modal.choose_remote_repository(repository_url)

    expect(install_modal).to have_private_theme_actions_enabled

    install_modal.stage_private_theme

    expect(install_modal).to be_closed
    expect(themes_page).to have_theme_named("private-theme")

    themes_page.click_edit_by_name("private-theme")
    expect(theme_page).to have_incomplete_installation
  end

  it "keeps installation unavailable when deploy key generation fails" do
    page.driver.with_playwright_page do |playwright_page|
      pattern = %r{/admin/themes/generate_key_pair}
      playwright_page.route(
        pattern,
        ->(route, _request) { route.fulfill(status: 422, body: '{"errors":["failed"]}') },
      )

      themes_page.visit
      install_modal = themes_page.click_install_button
      install_modal.choose_remote_repository(repository_url)
      expect(install_modal).to have_private_theme_actions_disabled
    ensure
      playwright_page.unroute(pattern)
    end
  end

  it "shows a categorized error when finishing the installation fails" do
    private_theme = Fabricate(:theme, name: "private-theme")
    private_theme.remote_theme =
      RemoteTheme.create!(remote_url: repository_url, private_key: "private key")
    private_theme.save!

    allow_any_instance_of(ThemeStore::GitImporter).to receive(:import!).and_raise(
      RemoteTheme::ImportError.new(I18n.t("themes.import_error.git_authentication")),
    )

    theme_page.visit(private_theme)
    theme_page.finish_install

    expect(dialog).to have_content(I18n.t("themes.import_error.git_authentication"))
  end
end
