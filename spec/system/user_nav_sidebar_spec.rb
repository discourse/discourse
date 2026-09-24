# frozen_string_literal: true

RSpec.describe "User nav sidebar" do
  fab!(:current_user) { Fabricate(:admin, username: "alice", refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, username: "bob", refresh_auto_groups: true) }
  fab!(:group) { Fabricate(:group, name: "cats", has_messages: true) }
  fab!(:group_message) do
    Fabricate(:group_private_message_topic, user: current_user, recipient_group: group)
  end

  let(:panel) { "#d-sidebar .sidebar-sections.user-nav-panel" }
  let(:sidebar_dropdown) { PageObjects::Components::SidebarHeaderDropdown.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.sidebar_user_navigation = true
    group.add(current_user)
    sign_in(current_user) unless RSpec.current_example.metadata[:anonymous]
  end

  def section(name)
    "#{panel} .sidebar-section-wrapper[data-section-name='user-nav-#{name}']"
  end

  it "takes over the sidebar on user routes and hides the navs it replaces" do
    visit("/u/alice/summary")

    expect(page).to have_css(panel)
    expect(page).to have_no_css(".user-navigation-primary")
    expect(page).to have_no_css("#d-sidebar .sidebar__panel-switch-button")
    expect(page).to have_css(".sidebar-filter__input")

    within(panel) do
      expect(page).to have_link("Summary")
      expect(page).to have_css("[data-section-name='user-nav-messages']")
    end
  end

  it "keeps the panel across every user tab and hands the sidebar back on the way out" do
    visit("/u/alice/activity")
    expect(page).to have_css(panel)

    visit("/u/alice/preferences/account")
    expect(page).to have_css(panel)

    visit("/latest")

    expect(page).to have_no_css(panel)
    expect(page).to have_css("#d-sidebar .sidebar-section-wrapper")
  end

  it "navigates between tabs from the panel" do
    visit("/u/alice/activity")

    find(panel).click_link("Summary")

    expect(page).to have_current_path("/u/alice/summary")
    expect(page).to have_css(
      "#d-sidebar .sidebar-section-link.active[data-link-name='user-nav-summary']",
    )
  end

  it "expands the section you are inside and nests its horizontal nav" do
    visit("/u/alice/activity")

    expect(page).to have_no_css(".user-navigation-secondary")
    expect(page).to have_css("#{section("activity")}.sidebar-section--expanded")

    # Read, Drafts and Bookmarks are gated on the user controller rather than
    # the user model, so they are easy to drop by accident.
    within(section("activity")) do
      %w[All Topics Replies Likes Read Drafts Bookmarks].each do |label|
        expect(page).to have_link(label)
      end
    end
  end

  it "links staff to the admin page for the user being viewed" do
    visit("/u/bob/summary")

    expect(find(panel)).to have_link("Manage user", href: "/admin/users/#{other_user.id}/bob")
    expect(find("#{section("profile")} .sidebar-section-link", match: :first).text).to eq(
      "Manage user",
    )
    # The panel carries it now, so the profile button would be a duplicate.
    expect(page).to have_no_css(".controls .user-admin")

    find(panel).click_link("Manage user")

    # An href link gets no active state from <LinkTo>, so the panel has to
    # report it, and must keep reporting it on the page's sub-routes.
    expect(page).to have_css(
      "#{panel} .sidebar-section-link.active[data-link-name='user-nav-admin']",
    )
  end

  it "keeps the panel on a user's admin page and leaves the back link alone" do
    visit("/u/bob/summary")
    find(panel).click_link("Manage user")

    expect(page).to have_current_path("/admin/users/#{other_user.id}/bob")
    expect(page).to have_css(panel)
    within(panel) { expect(page).to have_link("Summary") }
    expect(page).to have_css(".sidebar-sections__back-to-forum", text: "Back to Forum")
  end

  it "points the back link at admin when the admin area was the entry point" do
    visit("/admin/users/list/active")
    click_link("bob")

    expect(page).to have_current_path("/admin/users/#{other_user.id}/bob")
    expect(page).to have_css(panel)
    expect(page).to have_css(".sidebar-sections__back-to-forum", text: "Back to Admin")
    # Came from the users list, so its header and tabs are the trail back.
    expect(page).to have_css(".admin-users.admin-config-page")
  end

  it "drops the users config header when the profile was the entry point" do
    visit("/u/bob/summary")
    find(panel).click_link("Manage user")

    expect(page).to have_current_path("/admin/users/#{other_user.id}/bob")
    expect(page).to have_no_css(".admin-users.admin-config-page")
  end

  it "keeps the panel when the admin page hands back to a profile" do
    visit("/admin/users/#{other_user.id}/bob")
    expect(page).to have_css(panel)

    find(panel).click_link("Summary")

    expect(page).to have_current_path("/u/bob/summary")
    expect(page).to have_css(panel)
  end

  it "scopes the messages section to the selected inbox" do
    visit("/u/alice/messages")

    within(section("messages")) do
      %w[Latest Sent New Unread Archive].each { |label| expect(page).to have_link(label) }
    end

    # The bar keeps the controls that live in it; only the parts the panel
    # replaces go.
    expect(page).to have_css(".user-navigation-secondary .navigation-controls")
    expect(page).to have_no_css(".user-navigation-secondary .messages-nav a")

    visit("/u/alice/messages/group/cats")

    within(section("messages")) do
      expect(page).to have_link("Latest")
      expect(page).to have_no_link("Sent")
    end
  end

  def link_suffix(name)
    "#{panel} .sidebar-section-link[data-link-name='user-nav-#{name}'] " \
      ".sidebar-section-link-suffix.icon.unread"
  end

  def link_badge(name)
    "#{panel} .sidebar-section-link[data-link-name='user-nav-#{name}'] " \
      ".sidebar-section-link-content-badge"
  end

  it "marks drafts, unread messages and notifications, as a dot or a count" do
    # Never read, so it counts as new rather than unread.
    Fabricate(:private_message_post, user: other_user, recipient: current_user)
    Fabricate(:notification, user: current_user, read: false)
    Draft.set(current_user, "#{Draft::NEW_TOPIC}_1", 0, { reply: "a draft" }.to_json)

    visit("/u/alice/messages")
    expect(page).to have_css(link_suffix("messages-new"))

    visit("/u/alice/notifications")
    expect(page).to have_css(link_suffix("notifications-all"))

    # The count belongs in the suffix, not folded into the label.
    visit("/u/alice/activity")
    expect(page).to have_link("Drafts")
    expect(page).to have_css(link_suffix("activity-drafts"))

    current_user.user_option.update!(sidebar_show_count_of_new_items: true)

    visit("/u/alice/messages")
    expect(page).to have_css(link_badge("messages-new"), text: "1")
    expect(page).to have_no_css(link_suffix("messages-new"))

    visit("/u/alice/activity")
    expect(page).to have_link("Drafts")
    expect(page).to have_css(link_badge("activity-drafts"), text: "1")
  end

  it "leaves the counts off someone else's profile, since they track the viewer" do
    Fabricate(:private_message_post, user: other_user, recipient: current_user)

    visit("/u/bob/messages")

    expect(page).to have_css(panel)
    expect(page).to have_no_css(link_suffix("messages-new"))
    expect(page).to have_no_css(link_badge("messages-new"))
  end

  it "hides the horizontal navs on narrow screens, where the menu button serves the panel",
     mobile: true do
    visit("/u/alice/activity")

    expect(page).to have_no_css(".user-navigation-primary")
    expect(page).to have_no_css(".user-navigation-secondary")

    sidebar_dropdown.click

    expect(page).to have_css(
      ".sidebar-sections.user-nav-panel .sidebar-section-link[data-link-name='user-nav-summary']",
    )
  end

  it "switches inbox from the drawer on narrow screens", mobile: true do
    visit("/u/alice/messages")
    sidebar_dropdown.click

    find(".sidebar-sections.user-nav-panel .sidebar-more-section-links-details-summary").click
    find(".fk-d-menu-modal .sidebar-section-link", text: "cats").click

    expect(page).to have_current_path("/u/alice/messages/group/cats")
    # Picking an inbox is a navigation, so the menu gets out of the way.
    expect(page).to have_no_css(".sidebar-hamburger-dropdown")
  end

  it "serves the panel to anonymous visitors", anonymous: true do
    # A brand new user's profile is hidden from anonymous visitors, which would
    # leave the panel with nothing to show.
    SiteSetting.hide_new_user_profiles = false

    visit("/u/bob")

    expect(page).to have_css(panel)
    expect(page).to have_no_css(".user-navigation-primary")
    within(panel) { expect(page).to have_link("Summary") }

    # Everything that depends on who is viewing stays out.
    expect(page).to have_no_css(section("preferences"))
    expect(page).to have_no_css(section("messages"))
    expect(page).to have_no_link("Manage user")

    # Too few links left to be worth filtering.
    expect(page).to have_no_css(".sidebar-filter__input")
  end

  it "drops the messages bar when nothing is left in it" do
    # Someone else's inbox offers no new-message button, and the rest of the bar
    # is what the panel replaced, so the whole thing would be an empty shell.
    visit("/u/bob/messages")

    expect(page).to have_css(section("messages"))
    expect(page).to have_no_css(".user-navigation-secondary")
  end

  it "defers to the user controller for conditional tabs" do
    visit("/u/alice/summary")
    expect(page).to have_css(panel)
    expect(page).to have_no_link("Badges")

    BadgeGranter.grant(Badge.find(Badge::Autobiographer), current_user)

    visit("/u/alice/summary")
    within(panel) { expect(page).to have_link("Badges") }
  end

  it "leaves preferences to the panel rather than a button on your own profile" do
    visit("/u/alice/summary")

    expect(page).to have_no_css(".controls .user-preferences-btn")
    expect(page).to have_css(section("preferences"))
  end

  it "leaves the horizontal navs alone while the change is off" do
    SiteSetting.sidebar_user_navigation = false

    visit("/u/alice/summary")

    expect(page).to have_css(".user-navigation-primary")
    expect(page).to have_no_css(panel)

    # The admin user route records the entry point on every visit, so the
    # header it drives must stay put while the change is off.
    visit("/u/bob/summary")
    find(".controls .user-admin").click

    expect(page).to have_current_path("/admin/users/#{other_user.id}/bob")
    expect(page).to have_css(".admin-users.admin-config-page")
  end
end
