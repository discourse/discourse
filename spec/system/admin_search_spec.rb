# frozen_string_literal: true

describe "Admin Search", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  let(:search_modal) { PageObjects::Modals::AdminSearch.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(current_user) }

  it "can search for settings, pages, themes, components, and reports" do
    theme = Fabricate(:theme, name: "Discourse Invincible Theme")
    component = Fabricate(:theme, name: "Discourse Redacted", component: true)
    Theme
      .any_instance
      .stubs(:internal_translations)
      .returns([stub(key: "theme_metadata.description", value: "Some description")])

    visit "/admin"
    sidebar.click_search_input

    search_modal.search("min_topic_title")
    expect(search_modal.find_result("setting", 0)).to have_content("Min topic title length")
    expect(search_modal.find_result("setting", 0)).to have_content(
      I18n.t("site_settings.min_topic_title_length"),
    )

    search_modal.search("mau")
    expect(search_modal.find_result("report", 0)).to have_content(
      I18n.t("reports.dau_by_mau.title"),
    )
    expect(search_modal.find_result("report", 0)).to have_content(
      I18n.t("reports.dau_by_mau.description"),
    )

    search_modal.search("permalinks")
    expect(search_modal.find_result("page", 0)).to have_content(
      I18n.t("admin_js.admin.config.permalinks.title"),
    )
    expect(search_modal.find_result("page", 0)).to have_content(
      I18n.t("admin_js.admin.config.permalinks.header_description"),
    )

    search_modal.search("invincible")
    expect(search_modal.find_result("theme", 0)).to have_content("Discourse Invincible Theme")
    expect(search_modal.find_result("theme", 0)).to have_content("Some description")

    search_modal.search("redacted")
    expect(search_modal.find_result("component", 0)).to have_content("Discourse Redacted")
    expect(search_modal.find_result("component", 0)).to have_content("Some description")
  end

  it "can search full page" do
    visit "/admin"
    sidebar.click_search_input
    search_modal.search("min_topic_title")
    search_modal.input_enter
    expect(page).to have_current_path("/admin/search?filter=min_topic_title")
    expect(search_modal.find_result("setting", 0)).to have_content("Min topic title length")
    expect(search_modal.find_result("setting", 0)).to have_content(
      I18n.t("site_settings.min_topic_title_length"),
    )
  end

  it "informs user about no results" do
    visit "/admin"
    sidebar.click_search_input

    search_modal.search("very long search phrase")

    expect(search_modal).to have_content(
      'We couldn’t find anything matching "very long search phrase".',
    )
  end

  it "opens search modal with keyboard shortcut" do
    visit "/admin"

    send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "/"])
    expect(search_modal).to be_open
  end
end
