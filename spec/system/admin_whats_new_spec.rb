# frozen_string_literal: true

describe "Admin What's New Page" do
  let(:whats_new_page) { PageObjects::Pages::AdminWhatsNew.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  fab!(:admin)

  before do
    SiteSetting.navigation_menu = "sidebar"
    sign_in(admin)
  end

  def set_new_features_response_json(payload)
    UpcomingChanges.stubs(:permanent_upcoming_changes).returns([])
    Discourse.redis.set("new_features", MultiJson.dump(payload))
  end

  it "shows an error message when the backend returns an empty list" do
    set_new_features_response_json(nil)
    whats_new_page.visit
    expect(whats_new_page).to have_displayed_content(
      html_translation_to_text(
        I18n.t("admin_js.admin.dashboard.new_features.no_new_features_found"),
      ),
    )
  end

  it "displays a new feature indicator on the sidebar and clears it when navigating to what's new" do
    DiscourseUpdates.stubs(:has_unseen_features?).returns(true)
    set_new_features_response_json(
      [
        {
          "id" => 7,
          "user_id" => 1,
          "emoji" => "😍",
          "title" => "New feature",
          "description" => "New feature description",
          "link" => "https://meta.discourse.org",
          "tier" => [],
          "discourse_version" => "3.3.0.beta4",
          "created_at" => "2023-11-10T02:52:41.462Z",
          "updated_at" => "2023-11-10T04:28:47.020Z",
          "screenshot_url" =>
            "/uploads/default/original/1X/bab053dc94dc4e0d357b0e777e3357bb1ac99e12.jpeg",
        },
      ],
    )
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.toggle_all_sections
    expect(
      sidebar
        .find_section_link("admin_whats_new")
        .locator(".sidebar-section-link-suffix.admin-sidebar-nav-link__dot")
        .filter(visible: true),
    ).not_to have_count(0)
    sidebar.find_section_link("admin_whats_new").click
    expect(
      sidebar
        .find_section_link("admin_whats_new")
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator(".sidebar-section-link-suffix.admin-sidebar-nav-link__dot")
        .filter(visible: true),
    ).to have_count(0)
  end

  it "displays new features with screenshot taking precedence over emoji" do
    set_new_features_response_json(
      [
        {
          "id" => 7,
          "user_id" => 1,
          "emoji" => "😍",
          "title" => "New feature",
          "description" => "New feature description",
          "link" => "https://meta.discourse.org",
          "tier" => [],
          "discourse_version" => "3.3.0.beta4",
          "created_at" => "2023-11-10T02:52:41.462Z",
          "updated_at" => "2023-11-10T04:28:47.020Z",
          "screenshot_url" =>
            "/uploads/default/original/1X/bab053dc94dc4e0d357b0e777e3357bb1ac99e12.jpeg",
        },
        {
          "id" => 8,
          "user_id" => 1,
          "emoji" => "🐼",
          "title" => "New feature from previous release",
          "description" => "New feature description",
          "link" => "https://meta.discourse.org",
          "tier" => [],
          "discourse_version" => "3.3.0.beta3",
          "created_at" => "2023-09-10T02:52:41.462Z",
          "updated_at" => "2023-09-10T04:28:47.020Z",
          "released_at" => "2023-08-10T04:28:47.020Z",
          "screenshot_url" =>
            "/uploads/default/original/1X/bab054dc94dc4e0d357b0e777e3357bb1ac99e13.jpeg",
        },
      ],
    )

    whats_new_page.visit

    whats_new_page.within_new_feature_group("November 2023") do
      expect(whats_new_page).to have_screenshot
      expect(whats_new_page).to have_learn_more_link
      expect(whats_new_page).to have_no_emoji
      expect(whats_new_page).to have_date("November 2023")
    end

    whats_new_page.within_new_feature_group("August 2023") do
      expect(whats_new_page).to have_screenshot
      expect(whats_new_page).to have_learn_more_link
      expect(whats_new_page).to have_no_emoji
      expect(whats_new_page).to have_date("August 2023")
    end
  end

  it "displays new features with emoji when no screenshot" do
    set_new_features_response_json(
      [
        {
          "id" => 7,
          "user_id" => 1,
          "emoji" => "😍",
          "title" => "New feature",
          "description" => "New feature description",
          "link" => "https://meta.discourse.org",
          "tier" => [],
          "discourse_version" => "",
          "created_at" => "2023-11-10T02:52:41.462Z",
          "updated_at" => "2023-11-10T04:28:47.020Z",
        },
      ],
    )
    whats_new_page.visit
    whats_new_page.within_new_feature_item("New feature") do
      expect(whats_new_page).to have_emoji
      expect(whats_new_page).to have_no_screenshot
    end
  end
end
