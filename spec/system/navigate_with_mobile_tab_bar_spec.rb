# frozen_string_literal: true

RSpec.describe "Navigate with mobile tab bar", mobile: true do
  fab!(:current_user) { Fabricate(:admin, username: "alice", refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, username: "bob", refresh_auto_groups: true) }

  let(:tab_bar) { PageObjects::Components::MobileTabBar.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }
  let(:admin_menu) { ".sidebar-hamburger-dropdown .sidebar-sections.admin-panel" }
  let(:admin_page) { ".admin-menu .sidebar-panel-page" }
  let(:forum_menu) do
    ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name='community']"
  end

  before do
    SiteSetting.mobile_footer_navigation = true
    SiteSetting.chat_enabled = false if SiteSetting.respond_to?(:chat_enabled)
    SiteSetting.sidebar_user_navigation = true
    SiteSetting.hide_new_user_profiles = false
    sign_in(current_user)
  end

  it "takes the user back to where they left each section" do
    visit("/latest")

    expect(tab_bar).to have_tabs("main", "admin")
    expect(tab_bar).to have_active_tab("main")
    expect(page).to have_no_css(".hamburger-dropdown")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin/menu")
    expect(tab_bar).to have_active_tab("admin")

    find("#{admin_page} .sidebar-section-link", text: "Users").click

    expect(page).to have_current_path(%r{\A/admin/users})

    tab_bar.click_tab("main")

    expect(page).to have_current_path("/latest")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path(%r{\A/admin/users})

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin/menu")
  end

  it "opens the forum's menu from sections that hold their navigation on their own page" do
    visit("/admin/menu")

    expect(page).to have_css("#{admin_page} .sidebar-section-link", text: "Dashboard")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)
    expect(page).to have_no_css(admin_menu)
    expect(page).to have_css("#{admin_page} .sidebar-section-link", text: "Dashboard")
  end

  it "leaves links to topics and to sections with their own tab out of the menu" do
    visit("/latest")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)
    expect(page).to have_css("#{forum_menu} .sidebar-section-link[data-link-name='review']")
    expect(page).to have_css("#{forum_menu} .sidebar-section-link[data-link-name='invite']")
    expect(page).to have_no_css(".sidebar-section-link[data-link-name='everything']")
    expect(page).to have_no_css(".sidebar-section-link[data-link-name='admin']")
  end

  it "offers the user's drafts from the create button" do
    Draft.set(current_user, Draft::NEW_TOPIC, 0, { reply: "an unfinished thought" }.to_json)
    current_user.user_stat.update!(draft_count: 1)

    visit("/latest")

    tab_bar.click_create

    expect(tab_bar).to have_create_actions("New topic", "New personal message", "Drafts (1)")

    tab_bar.click_create_action("Drafts (1)")

    expect(page).to have_current_path("/u/#{current_user.username}/activity/drafts")
  end

  it "holds the topic list's views and less frequent actions beside the tab bar" do
    Fabricate(:post)
    topic_list = PageObjects::Components::TopicList.new

    visit("/latest")

    expect(page).to have_css(".mobile-tab-bar__views #navigation-bar .nav-item_latest a.active")
    expect(page).to have_css(".category-breadcrumb:not(.hidden) .category-drop")
    expect(page).to have_no_css(".navigation-controls .bulk-select")

    find(".mobile-tab-bar__views .navigation-options__trigger").click
    find(".navigation-options__bulk-select").click

    expect(topic_list).to have_bulk_select_enabled

    visit("/categories")

    expect(page).to have_css("#create-category", text: "New category")
    expect(page).to have_no_css(".category-breadcrumb")

    find(".mobile-tab-bar__views .navigation-options__trigger").click

    expect(page).to have_css(".navigation-options__reorder-categories")
    expect(page).to have_no_css(".navigation-options__bulk-select")
  end

  it "dismisses new and unread topics from the options beside the list's views" do
    current_user.user_option.update!(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)
    Fabricate.times(2, :post)
    unread = Fabricate(:post).topic
    Fabricate(:post, topic: unread)
    TopicUser.update_last_read(current_user, unread.id, 1, 1, 0)
    TopicUser.change(
      current_user.id,
      unread.id,
      notification_level: TopicUser.notification_levels[:tracking],
    )
    topic_list = PageObjects::Components::TopicList.new

    visit("/unread")

    expect(topic_list).to have_topic(unread)
    expect(page).to have_no_css(".dismiss-container-top")

    find(".mobile-tab-bar__views .navigation-options__trigger").click
    find(".navigation-options__dismiss-read").click
    find("#dismiss-read-confirm").click

    expect(topic_list).to have_no_topics

    visit("/new")

    expect(topic_list).to have_topics
    expect(page).to have_no_css(".dismiss-container-top")

    find(".mobile-tab-bar__views .navigation-options__trigger").click
    find(".navigation-options__dismiss-new").click

    expect(topic_list).to have_no_topics
  end

  it "keeps the list's own controls on a tag intersection, which has no views beside the tabs" do
    SiteSetting.tagging_enabled = true
    sour = Fabricate(:tag, name: "sour")
    tangy = Fabricate(:tag, name: "tangy")
    Fabricate(:topic, tags: [sour, tangy])

    visit("/tags/intersection/sour/tangy")

    expect(page).to have_no_css(".mobile-tab-bar__views #navigation-bar")
    expect(page).to have_css(".navigation-controls .bulk-select")
  end

  it "fixes category positions only after admins save an order from the category list" do
    SiteSetting.fixed_category_positions = false

    visit("/categories")
    find(".mobile-tab-bar__views .navigation-options__trigger").click

    expect(page).to have_css(
      ".navigation-options__page-layout[href*='/admin/config/category-management/settings?filter=category_page_style']",
    )

    find(".navigation-options__reorder-categories").click

    expect(page).to have_css(".reorder-categories")
    expect(SiteSetting.fixed_category_positions).to eq(false)

    page.refresh

    expect(page).to have_css(".mobile-tab-bar__views .navigation-options__trigger")
    expect(SiteSetting.fixed_category_positions).to eq(false)

    find(".mobile-tab-bar__views .navigation-options__trigger").click
    find(".navigation-options__reorder-categories").click
    find(".d-modal .modal-close").click

    expect(page).to have_no_css(".reorder-categories")
    try_until_success { expect(SiteSetting.fixed_category_positions).to eq(false) }

    find(".mobile-tab-bar__views .navigation-options__trigger").click
    find(".navigation-options__reorder-categories").click
    first(".reorder-categories .move-down").click
    find(".d-modal__footer .btn-primary").click

    expect(page).to have_no_css(".reorder-categories")
    expect(SiteSetting.fixed_category_positions).to eq(true)
  end

  it "lets members who can edit a topic's title, category and tags do so from the header" do
    SiteSetting.edit_all_topic_groups = Group::AUTO_GROUPS[:trust_level_0]
    topic = Fabricate(:post, user: Fabricate(:user)).topic
    sign_in(other_user)

    visit(topic.url)

    expect(page).to have_no_css("#topic-title")

    find(".d-header .header-title__edit").click

    expect(page).to have_css("#topic-title .edit-topic-title #edit-title")
  end

  it "lets the user reply to the topic they're reading from the create button" do
    topic = Fabricate(:post).topic

    visit(topic.url)
    tab_bar.click_create

    expect(tab_bar).to have_create_actions("Reply to topic", "New topic", "New personal message")

    tab_bar.click_create_action("Reply to topic")

    expect(page).to have_css("#reply-control.open .composer-action-title", text: topic.title)
  end

  it "tucks the list's views away while scrolling down, and brings them back on the way up" do
    Fabricate.times(30, :post)

    visit("/latest")

    expect(page).to have_css(".mobile-tab-bar__views #navigation-bar")
    expect(page).to have_no_css(".mobile-tab-bar.--views-tucked")

    # Scrolling counts only once a page settles, so keep scrolling down
    # between the same points, clear of the page's ends, until it does
    8.times do
      page.execute_script("window.scrollTo(0, 300)")
      sleep 0.2
      page.execute_script("window.scrollTo(0, 700)")
      sleep 0.5
      break if page.evaluate_script("!!document.querySelector('.mobile-tab-bar.--views-tucked')")
    end

    expect(page).to have_css(".mobile-tab-bar.--views-tucked")

    page.execute_script("window.scrollTo(0, 400)")

    expect(page).to have_no_css(".mobile-tab-bar.--views-tucked")
  end

  it "hides the topic's progress at the end of the topic rather than leaving it to scroll away" do
    topic = Fabricate(:topic)
    Fabricate.times(8, :post, topic: topic)

    visit(topic.url)

    expect(page).to have_css("#topic-progress-wrapper:not(.docked) #topic-progress .nums")

    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

    expect(page).to have_css("#topic-progress-wrapper.docked", visible: :hidden)

    page.execute_script("window.scrollTo(0, 0)")

    expect(page).to have_css("#topic-progress-wrapper:not(.docked) #topic-progress .nums")
  end

  it "offers a new topic only where the topic list would" do
    SiteSetting.hide_disabled_create_topic_button = true
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
    category = Fabricate(:category)
    category.set_permissions(everyone: :readonly)
    category.save!
    sign_in(other_user)

    visit(category.url)

    expect(page).to have_css(".mobile-tab-bar__create[aria-label='New personal message']")
  end

  it "lets moderators who manage categories reorder them once their positions are fixed" do
    SiteSetting.moderators_manage_categories = true
    SiteSetting.fixed_category_positions = true
    sign_in(Fabricate(:moderator, refresh_auto_groups: true))

    visit("/categories")
    find(".mobile-tab-bar__views .navigation-options__trigger").click

    expect(page).to have_css(".navigation-options__reorder-categories")
    expect(page).to have_no_css(".navigation-options__page-layout")
  end

  it "lets the user start a topic in the category they're looking at from the create button" do
    category = Fabricate(:category)
    visit(category.url)

    expect(page).to have_css(".navigation-container")
    expect(page).to have_no_css("#create-topic")

    tab_bar.click_create

    expect(tab_bar).to have_create_actions("New topic", "New personal message")

    tab_bar.click_create_action("New topic")

    expect(page).to have_css("#reply-control.open")
    expect(PageObjects::Components::SelectKit.new(".category-chooser")).to have_selected_value(
      category.id,
    )
  end

  it "takes the user from a topic back to the list they opened it from when they tap the current tab" do
    category = Fabricate(:category)
    topic = Fabricate(:post, topic: Fabricate(:topic, category:)).topic
    visit(category.url)

    PageObjects::Components::TopicList.new.visit_topic(topic)

    expect(page).to have_current_path(%r{\A/t/})
    expect(page).to have_css("html.mobile-tab-bar-nested")

    tab_bar.click_tab("main")

    expect(page).to have_current_path(category.url)
  end

  it "shows the full logo on a section's top level and a back button below it" do
    category = Fabricate(:category)
    topic = Fabricate(:post, topic: Fabricate(:topic, category:)).topic
    visit(category.url)

    expect(page).to have_css(".d-header .title:not(.title--minimized)")
    expect(page).to have_no_css(".mobile-tab-bar-back")

    PageObjects::Components::TopicList.new.visit_topic(topic)

    expect(page).to have_css(".mobile-tab-bar-back")
    expect(page).to have_css(".d-header .extra-info-wrapper", text: topic.title)
    expect(page).to have_no_css(".d-header .title--minimized", visible: :visible)

    find(".mobile-tab-bar-back").click

    expect(page).to have_current_path(category.url)

    visit("/admin/users")

    expect(page).to have_css(".mobile-tab-bar-back")
    expect(page).to have_css(".d-header .mobile-tab-bar-title", text: "Users")
    expect(page).to have_no_css(".d-page-header__title", visible: :visible)

    find(".mobile-tab-bar-back").click

    expect(page).to have_current_path("/admin/menu")
    expect(page).to have_no_css(".mobile-tab-bar-back")
    expect(page).to have_css(".d-header .title:not(.title--minimized)")
  end

  it "takes the user to search from the header, a page of its own outside the sections" do
    visit("/latest")

    find(".d-header-icons .search-dropdown").click

    expect(page).to have_current_path("/search")
    expect(tab_bar).to have_no_active_tab
  end

  it "leaves pages of their own outside the topics section" do
    visit("/filter")

    expect(tab_bar).to have_no_active_tab

    visit("/g")

    expect(tab_bar).to have_no_active_tab

    visit(
      "/c/#{Category.find(SiteSetting.uncategorized_category_id).slug}/#{SiteSetting.uncategorized_category_id}",
    )

    expect(tab_bar).to have_active_tab("main")
  end

  it "keeps profile navigation on the page, outside every section" do
    visit("/u/bob/summary")

    expect(tab_bar).to have_no_active_tab
    expect(page).to have_css(".user-navigation-primary")

    visit("/u/alice/summary")

    expect(page).to have_css(".user-navigation-primary")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)
  end

  it "keeps each tab leading to its own section after a profile opened from it" do
    visit("/admin/menu")
    user_menu.open.click_profile_tab
    find("#quick-access-profile .summary a").click

    expect(page).to have_current_path("/u/#{current_user.username}/summary")
    expect(tab_bar).to have_no_active_tab
    expect(page).to have_no_css(".mobile-tab-bar-back")
    expect(page).to have_no_css(".mobile-tab-bar-title")

    tab_bar.click_tab("main")

    expect(page).to have_no_current_path(%r{\A/u/})
    expect(tab_bar).to have_active_tab("main")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin/menu")
  end

  it "keeps notifications and the profile tab together in the user menu" do
    visit("/latest")

    expect(page).to have_css("#toggle-current-user img.avatar")

    user_menu.open

    expect(page).to have_css("#user-menu-button-all-notifications")
    expect(page).to have_css("#user-menu-button-profile")
  end

  it "gives members without other sections the forum tab" do
    sign_in(other_user)

    visit("/latest")

    expect(tab_bar).to have_tabs("main")
    expect(page).to have_css(".mobile-tab-bar__create")
    expect(page).to have_css("#toggle-current-user img.avatar")
    expect(page).to have_no_css(".hamburger-dropdown")
  end
end
