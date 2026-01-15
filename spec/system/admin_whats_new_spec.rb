# frozen_string_literal: true

describe "Admin What's New Page", type: :system do
  let(:whats_new_page) { PageObjects::Pages::AdminWhatsNew.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  fab!(:admin)

  before do
    SiteSetting.navigation_menu = "sidebar"
    sign_in(admin)
  end

  def set_new_features_payload(payload)
    Discourse.redis.set("new_features", MultiJson.dump(payload))
  end

  it "shows an error message when the backend returns an empty list" do
    set_new_features_payload(nil)
    whats_new_page.visit
    expect(whats_new_page).to have_content("There was an error loading the feed.")
  end

  it "displays a new feature indicator on the sidebar and clears it when navigating to what's new" do
    DiscourseUpdates.stubs(:has_unseen_features?).returns(true)
    set_new_features_payload(
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

  it "displays new features with screenshot taking precedence over emoji" do
    set_new_features_payload(
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
    set_new_features_payload(
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
    expect(whats_new_page).to have_emoji
    expect(whats_new_page).to have_no_screenshot
  end

  describe "items with a related_site_setting" do
    before do
      set_new_features_payload(
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
            "related_site_setting" => "experimental_form_templates",
            "experiment" => false,
          },
        ],
      )
    end

    it "toggles the attached site setting and shows the correct state" do
      whats_new_page.visit
      whats_new_page.within_new_feature_item("New feature") do
        expect(whats_new_page.enable_item_toggle.unchecked?).to be_truthy
        whats_new_page.enable_item_toggle.toggle
      end
      expect(page).to have_content(I18n.t("admin_js.admin.dashboard.new_features.feature_enabled"))
      whats_new_page.visit
      expect(SiteSetting.experimental_form_templates).to be true
      expect(whats_new_page.enable_item_toggle.checked?).to be_truthy
    end
  end

  describe "experimental items" do
    it "displays experimental feature toggle and has the correct state" do
      set_new_features_payload(
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
            "related_site_setting" => "experimental_form_templates",
            "experiment" => false,
          },
        ],
      )
      whats_new_page.visit
      expect(whats_new_page).to have_toggle_feature_button()
    end

    it "displays experimental text next to feature title when feature is experimental" do
      set_new_features_payload(
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
            "related_site_setting" => "experimental_form_templates",
            "experiment" => true,
          },
        ],
      )
      whats_new_page.visit
      expect(whats_new_page).to have_experimental_text
    end

    it "does not display experimental text next to feature title when feature is not experimental" do
      set_new_features_payload(
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
      expect(whats_new_page).to have_no_experimental_text
    end

    it "allows filtering to only show experimental items" do
      set_new_features_payload(
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
            "related_site_setting" => "experimental_form_templates",
            "experiment" => true,
          },
          {
            "id" => 8,
            "user_id" => 1,
            "emoji" => "🥹",
            "title" => "Non experimental feature",
            "description" => "Cool description",
            "link" => "https://meta.discourse.org",
            "tier" => [],
            "discourse_version" => "",
            "created_at" => "2023-11-10T02:52:41.462Z",
            "updated_at" => "2023-11-10T04:28:47.020Z",
            "related_site_setting" => nil,
            "experiment" => false,
          },
        ],
      )
      whats_new_page.visit
      whats_new_page.toggle_experiments_only
      expect(whats_new_page).to have_experimental_text
    end
  end
end
