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
    browser_page.goto("/u/alice/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
    expect(
      browser_root.locator(".user-navigation-primary").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("#d-sidebar .sidebar__panel-switch-button").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".sidebar-filter__input").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    within_browser(panel) do
      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{"Summary".to_s.to_json}], [name=#{"Summary".to_s.to_json}]",
            ).or(browser_root.get_by_role("link", name: "Summary")),
          )
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-section-name='user-nav-messages']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  it "keeps the panel across every user tab and hands the sidebar back on the way out" do
    browser_page.goto("/u/alice/activity").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )

    browser_page
      .goto("/u/alice/preferences/account")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(panel).filter(visible: true)).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("#d-sidebar .sidebar-section-wrapper").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "navigates between tabs from the panel" do
    browser_page.goto("/u/alice/activity").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root
      .locator(panel)
      .filter(visible: true)
      .locator("[id=#{"Summary".to_s.to_json}], [name=#{"Summary".to_s.to_json}]")
      .or(browser_root.locator(panel).filter(visible: true).get_by_role("link", name: "Summary"))
      .filter(visible: true)
      .click

    expect(browser_page).to PlaywrightMatchers.have_url("/u/alice/summary")
    expect(
      browser_root.locator(
        "#d-sidebar .sidebar-section-link.active[data-link-name='user-nav-summary']",
      ).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "expands the section you are inside and nests its horizontal nav" do
    browser_page.goto("/u/alice/activity").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".user-navigation-secondary").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("#{section("activity")}.sidebar-section--expanded").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)

    # Read, Drafts and Bookmarks are gated on the user controller rather than
    # the user model, so they are easy to drop by accident.
    within_browser(section("activity")) do
      %w[All Topics Replies Likes Read Drafts Bookmarks].each do |label|
        expect(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator("[id=#{label.to_s.to_json}], [name=#{label.to_s.to_json}]").or(
                browser_root.get_by_role("link", name: label),
              ),
            )
            .filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end
  end

  it "links staff to the admin page for the user being viewed" do
    browser_page.goto("/u/bob/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root
        .locator(panel)
        .filter(visible: true)
        .get_by_role("link")
        .and(
          browser_root
            .locator(panel)
            .filter(visible: true)
            .locator("[id=#{"Manage user".to_s.to_json}], [name=#{"Manage user".to_s.to_json}]")
            .or(
              browser_root
                .locator(panel)
                .filter(visible: true)
                .get_by_role("link", name: "Manage user"),
            ),
        )
        .and(
          browser_root
            .locator(panel)
            .filter(visible: true)
            .locator("[href=#{"/admin/users/#{other_user.id}/bob".to_s.to_json}]"),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root
        .locator("#{section("profile")} .sidebar-section-link")
        .filter(visible: true)
        .first
        .inner_text
        .strip,
    ).to eq("Manage user")
    # The panel carries it now, so the profile button would be a duplicate.
    expect(
      browser_root.locator(".controls .user-admin").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    browser_root
      .locator(panel)
      .filter(visible: true)
      .locator("[id=#{"Manage user".to_s.to_json}], [name=#{"Manage user".to_s.to_json}]")
      .or(
        browser_root.locator(panel).filter(visible: true).get_by_role("link", name: "Manage user"),
      )
      .filter(visible: true)
      .click

    # An href link gets no active state from <LinkTo>, so the panel has to
    # report it, and must keep reporting it on the page's sub-routes.
    expect(
      browser_root.locator(
        "#{panel} .sidebar-section-link.active[data-link-name='user-nav-admin']",
      ).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "keeps the panel on a user's admin page and leaves the back link alone" do
    browser_page.goto("/u/bob/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root
      .locator(panel)
      .filter(visible: true)
      .locator("[id=#{"Manage user".to_s.to_json}], [name=#{"Manage user".to_s.to_json}]")
      .or(
        browser_root.locator(panel).filter(visible: true).get_by_role("link", name: "Manage user"),
      )
      .filter(visible: true)
      .click

    expect(browser_page).to PlaywrightMatchers.have_url("/admin/users/#{other_user.id}/bob")
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
    within_browser(panel) do
      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{"Summary".to_s.to_json}], [name=#{"Summary".to_s.to_json}]",
            ).or(browser_root.get_by_role("link", name: "Summary")),
          )
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
    expect(
      browser_root.locator(".sidebar-sections__back-to-forum").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Back to Forum")],
      useInnerText: true,
    )
    expect(
      browser_root.locator(section("preferences")).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "points the back link at admin when the admin area was the entry point" do
    browser_page
      .goto("/admin/users/list/active")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator("a[href='/admin/users/#{other_user.id}/bob']").filter(visible: true).click

    expect(browser_page).to PlaywrightMatchers.have_url("/admin/users/#{other_user.id}/bob")
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
    expect(
      browser_root.locator(".sidebar-sections__back-to-forum").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Back to Admin")],
      useInnerText: true,
    )
    # Came from the users list, so its header and tabs are the trail back.
    expect(
      browser_root.locator(".admin-users.admin-config-page").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "drops the users config header when the profile was the entry point" do
    browser_page.goto("/u/bob/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root
      .locator(panel)
      .filter(visible: true)
      .locator("[id=#{"Manage user".to_s.to_json}], [name=#{"Manage user".to_s.to_json}]")
      .or(
        browser_root.locator(panel).filter(visible: true).get_by_role("link", name: "Manage user"),
      )
      .filter(visible: true)
      .click

    expect(browser_page).to PlaywrightMatchers.have_url("/admin/users/#{other_user.id}/bob")
    expect(
      browser_root.locator(".admin-users.admin-config-page").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "keeps the panel when the admin page hands back to a profile" do
    browser_page
      .goto("/admin/users/#{other_user.id}/bob")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )

    browser_root
      .locator(panel)
      .filter(visible: true)
      .locator("[id=#{"Summary".to_s.to_json}], [name=#{"Summary".to_s.to_json}]")
      .or(browser_root.locator(panel).filter(visible: true).get_by_role("link", name: "Summary"))
      .filter(visible: true)
      .click

    expect(browser_page).to PlaywrightMatchers.have_url("/u/bob/summary")
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
  end

  it "scopes the messages section to the selected inbox" do
    browser_page.goto("/u/alice/messages").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    within_browser(section("messages")) do
      %w[Latest Sent New Unread Archive].each do |label|
        expect(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator("[id=#{label.to_s.to_json}], [name=#{label.to_s.to_json}]").or(
                browser_root.get_by_role("link", name: label),
              ),
            )
            .filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    # The bar keeps the controls that live in it; only the parts the panel
    # replaces go.
    expect(
      browser_root.locator(".user-navigation-secondary .navigation-controls").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".user-navigation-secondary .messages-nav a").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    browser_page
      .goto("/u/alice/messages/group/cats")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    within_browser(section("messages")) do
      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{"Latest".to_s.to_json}], [name=#{"Latest".to_s.to_json}]",
            ).or(browser_root.get_by_role("link", name: "Latest")),
          )
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator("[id=#{"Sent".to_s.to_json}], [name=#{"Sent".to_s.to_json}]").or(
              browser_root.get_by_role("link", name: "Sent"),
            ),
          )
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
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

  it "marks drafts and unread messages, as a dot or a count" do
    # Never read, so it counts as new rather than unread.
    Fabricate(:private_message_post, user: other_user, recipient: current_user)
    Draft.set(current_user, "#{Draft::NEW_TOPIC}_1", 0, { reply: "a draft" }.to_json)

    browser_page.goto("/u/alice/messages").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(link_suffix("messages-new")).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    # The count belongs in the suffix, not folded into the label.
    browser_page.goto("/u/alice/activity").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root
        .get_by_role("link")
        .and(
          browser_root.locator("[id=#{"Drafts".to_s.to_json}], [name=#{"Drafts".to_s.to_json}]").or(
            browser_root.get_by_role("link", name: "Drafts"),
          ),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(link_suffix("activity-drafts")).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    current_user.user_option.update!(sidebar_show_count_of_new_items: true)

    browser_page.goto("/u/alice/messages").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(link_badge("messages-new")).filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("1")], useInnerText: true)
    expect(
      browser_root.locator(link_suffix("messages-new")).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    browser_page.goto("/u/alice/activity").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root
        .get_by_role("link")
        .and(
          browser_root.locator("[id=#{"Drafts".to_s.to_json}], [name=#{"Drafts".to_s.to_json}]").or(
            browser_root.get_by_role("link", name: "Drafts"),
          ),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(link_badge("activity-drafts")).filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("1")], useInnerText: true)
  end

  it "leaves the counts off someone else's profile, since they track the viewer" do
    Fabricate(:private_message_post, user: other_user, recipient: current_user)

    browser_page.goto("/u/bob/messages").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
    expect(
      browser_root.locator(link_suffix("messages-new")).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(link_badge("messages-new")).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "hides the horizontal navs on narrow screens, where the menu button serves the panel",
     mobile: true do
    browser_page.goto("/u/alice/activity").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".user-navigation-primary").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".user-navigation-secondary").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    sidebar_dropdown.click

    expect(
      browser_root.locator(
        ".sidebar-sections.user-nav-panel .sidebar-section-link[data-link-name='user-nav-summary']",
      ).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "switches inbox from the drawer on narrow screens", mobile: true do
    browser_page.goto("/u/alice/messages").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar_dropdown.click

    browser_root
      .locator(".sidebar-sections.user-nav-panel .sidebar-more-section-links-details-summary")
      .filter(visible: true)
      .click
    browser_root
      .locator(".fk-d-menu-modal .sidebar-section-link")
      .filter(visible: true)
      .filter(hasText: browser_text_pattern("cats"))
      .click

    expect(browser_page).to PlaywrightMatchers.have_url("/u/alice/messages/group/cats")
    # Picking an inbox is a navigation, so the menu gets out of the way.
    expect(
      browser_root.locator(".sidebar-hamburger-dropdown").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "serves the panel to anonymous visitors", anonymous: true do
    # A brand new user's profile is hidden from anonymous visitors, which would
    # leave the panel with nothing to show.
    SiteSetting.hide_new_user_profiles = false

    browser_page.goto("/u/bob").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
    expect(
      browser_root.locator(".user-navigation-primary").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    within_browser(panel) do
      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{"Summary".to_s.to_json}], [name=#{"Summary".to_s.to_json}]",
            ).or(browser_root.get_by_role("link", name: "Summary")),
          )
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    # Everything that depends on who is viewing stays out.
    expect(
      browser_root.locator(section("preferences")).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(section("messages")).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root
        .get_by_role("link")
        .and(
          browser_root.locator(
            "[id=#{"Manage user".to_s.to_json}], [name=#{"Manage user".to_s.to_json}]",
          ).or(browser_root.get_by_role("link", name: "Manage user")),
        )
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    # Too few links left to be worth filtering.
    expect(
      browser_root.locator(".sidebar-filter__input").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "drops the messages bar when nothing is left in it" do
    # Someone else's inbox offers no new-message button, and the rest of the bar
    # is what the panel replaced, so the whole thing would be an empty shell.
    browser_page.goto("/u/bob/messages").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(section("messages")).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".user-navigation-secondary").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "defers to the user controller for conditional tabs" do
    browser_page.goto("/u/alice/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(panel).filter(visible: true)).not_to PlaywrightMatchers.have_count(
      0,
    )
    expect(
      browser_root
        .get_by_role("link")
        .and(
          browser_root.locator("[id=#{"Badges".to_s.to_json}], [name=#{"Badges".to_s.to_json}]").or(
            browser_root.get_by_role("link", name: "Badges"),
          ),
        )
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    BadgeGranter.grant(Badge.find(Badge::Autobiographer), current_user)

    browser_page.goto("/u/alice/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    within_browser(panel) do
      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{"Badges".to_s.to_json}], [name=#{"Badges".to_s.to_json}]",
            ).or(browser_root.get_by_role("link", name: "Badges")),
          )
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  it "leaves preferences to the panel rather than a button on your own profile" do
    browser_page.goto("/u/alice/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".controls .user-preferences-btn").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(section("preferences")).filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "leaves the horizontal navs alone while the change is off" do
    SiteSetting.sidebar_user_navigation = false

    browser_page.goto("/u/alice/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".user-navigation-primary").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(browser_root.locator(panel).filter(visible: true)).to PlaywrightMatchers.have_count(0)

    # The admin user route records the entry point on every visit, so the
    # header it drives must stay put while the change is off.
    browser_page.goto("/u/bob/summary").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".controls .user-admin").filter(visible: true).click

    expect(browser_page).to PlaywrightMatchers.have_url("/admin/users/#{other_user.id}/bob")
    expect(
      browser_root.locator(".admin-users.admin-config-page").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end
end
