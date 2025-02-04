# frozen_string_literal: true

describe "Admin New Features Page", type: :system do
  let(:new_features_page) { PageObjects::Pages::AdminNewFeatures.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  fab!(:admin)

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.admin_sidebar_enabled_groups = [
      Group::AUTO_GROUPS[:admins],
      Group::AUTO_GROUPS[:moderators],
    ]
    sign_in(admin)
  end

  it "displays new features with screenshot taking precedence over emoji" do
    DiscourseUpdates.stubs(:new_features).returns(
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

    new_features_page.visit

    within find(".admin-config-area-card:first-child") do
      expect(new_features_page).to have_screenshot
      expect(new_features_page).to have_learn_more_link
      expect(new_features_page).to have_no_emoji
      expect(new_features_page).to have_date("November 2023")
    end

    within find(".admin-config-area-card:last-child") do
      expect(new_features_page).to have_screenshot
      expect(new_features_page).to have_learn_more_link
      expect(new_features_page).to have_no_emoji
      expect(new_features_page).to have_date("August 2023")
    end
  end

  it "displays new features with emoji when no screenshot" do
    DiscourseUpdates.stubs(:new_features).returns(
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
    new_features_page.visit
    expect(new_features_page).to have_emoji
    expect(new_features_page).to have_no_screenshot
  end

  it "displays experimental feature toggle and has the correct state" do
    DiscourseUpdates.stubs(:new_features).returns(
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
          "experiment_setting" => "experimental_form_templates",
          "experiment_enabled" => true,
        },
      ],
    )
    new_features_page.visit
    expect(new_features_page).to have_toggle_experiment_button(true)
  end

  it "displays experimental text next to feature title when feature is experimental" do
    DiscourseUpdates.stubs(:new_features).returns(
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
          "experiment_setting" => "experimental_form_templates",
          "experiment_enabled" => true,
        },
      ],
    )
    new_features_page.visit
    expect(new_features_page).to have_experimental_text
  end

  it "does not display experimental text next to feature title when feature is not experimental" do
    DiscourseUpdates.stubs(:new_features).returns(
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
    new_features_page.visit
    expect(new_features_page).to have_no_experimental_text
  end

  it "displays a new feature indicator on the sidebar and clears it when navigating to what's new" do
    DiscourseUpdates.stubs(:has_unseen_features?).returns(true)
    visit "/admin"
    sidebar.toggle_all_sections
    expect(sidebar.find_section_link("admin_whats_new")).to have_css(
      ".sidebar-section-link-suffix.admin-sidebar-nav-link__dot",
    )
    sidebar.find_section_link("admin_whats_new").click
    expect(sidebar.find_section_link("admin_whats_new")).to have_no_css(
      ".sidebar-section-link-suffix.admin-sidebar-nav-link__dot",
    )
  end
end
