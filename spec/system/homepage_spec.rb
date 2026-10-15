# frozen_string_literal: true

describe "Homepage" do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }
  let(:discovery) { PageObjects::Pages::Discovery.new }
  fab!(:theme)
  let(:user_preferences_interface_page) { PageObjects::Pages::UserPreferencesInterface.new }

  before do
    # A workaround to avoid the global notice from interfering with the tests
    # It is coming from the ensure_login_hint.rb initializer and it gets
    # evaluated before the tests run (and it wrongly counts 0 admins defined)
    SiteSetting.global_notice = ""
  end

  it "shows a list of topics by default" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 5)
  end

  it "allows users to pick their homepage" do
    sign_in user
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .latest.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Latest")], useInnerText: true)

    user_preferences_interface_page.visit(user)

    homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
    homepage_picker.expand
    homepage_picker.select_row_by_name("Hot")

    user_preferences_interface_page.save_changes

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .hot.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Hot")], useInnerText: true)
  end

  it "allows users to reset their homepage preference to the site default" do
    user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("hot"))
    SiteSetting.default_homepage = "categories"

    sign_in user
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .hot.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Hot")], useInnerText: true)

    user_preferences_interface_page.visit(user)

    homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
    homepage_picker.expand
    homepage_picker.select_row_by_name("Default")

    user_preferences_interface_page.save_changes

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .categories.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Categories")], useInnerText: true)
  end

  it "defaults to first top_menu item as anonymous homepage when default_homepage is not set" do
    SiteSetting.top_menu = "categories|latest|new"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .categories.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Categories")], useInnerText: true)
  end

  it "uses default_homepage for both anonymous and logged-in users" do
    SiteSetting.default_homepage = "categories"
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .categories.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Categories")], useInnerText: true)

    sign_in user
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".navigation-container .categories.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Categories")], useInnerText: true)
  end

  it "diverges for a user-scoped homepage: logged-in users get it, anon falls back" do
    SiteSetting.top_menu = "latest|new|bookmarks|categories"
    SiteSetting.default_homepage = "bookmarks"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_page).to PlaywrightMatchers.have_url("/")
    expect(
      browser_root.locator(".navigation-container .latest.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Latest")], useInnerText: true)

    sign_in user
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_page).to PlaywrightMatchers.have_url("/")
    expect(
      browser_root.locator(".navigation-container .bookmarks.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Bookmarks")], useInnerText: true)
  end

  it "renders an empty state when a user-scoped homepage has no content" do
    SiteSetting.top_menu = "latest|new|bookmarks|categories"
    SiteSetting.default_homepage = "bookmarks"

    sign_in user
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_page).to PlaywrightMatchers.have_url("/")
    expect(
      browser_root.locator(".navigation-container .bookmarks.active").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Bookmarks")], useInnerText: true)
    expect(discovery.topic_list).to have_no_topics
  end

  it "renders the homepage but highlights no nav tab when the homepage is not a top_menu item" do
    SiteSetting.top_menu = "latest|new|categories"
    SiteSetting.default_homepage = "top"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".list-container").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".nav-item_top").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".navigation-container .active").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  shared_examples "a custom homepage" do
    it "shows the custom homepage component" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".new-home").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Hi friends!")],
        useInnerText: true,
      )
      expect(
        browser_root.locator(".list-container").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      browser_root
        .locator("#sidebar-section-content-community li:first-child")
        .filter(visible: true)
        .click
      expect(
        browser_root.locator(".list-container").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      click_logo

      expect(
        browser_root.locator(".list-container").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      # ensure clicking on logo brings user back to the custom homepage
      expect(
        browser_root.locator(".new-home").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Hi friends!")],
        useInnerText: true,
      )
    end

    it "respects the user's homepage choice" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".list-container").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".new-home").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Hi friends!")],
        useInnerText: true,
      )

      sign_in user

      browser_page.goto("").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(
        browser_root.locator(".new-home").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Hi friends!")],
        useInnerText: true,
      )

      user_preferences_interface_page.visit(user)

      homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
      homepage_picker.expand
      # user overrides theme custom homepage
      homepage_picker.select_row_by_name("Hot")
      user_preferences_interface_page.save_changes

      expect(user.user_option.homepage_id).to eq(UserOption::HOMEPAGES.key("hot"))

      click_logo

      expect(
        browser_root.locator(".navigation-container .hot.active").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("Hot")], useInnerText: true)

      user_preferences_interface_page.visit(user)

      homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
      homepage_picker.expand
      # user selects theme custom homepage again
      homepage_picker.select_row_by_name("Default")
      user_preferences_interface_page.save_changes

      click_logo

      expect(browser_page).to PlaywrightMatchers.have_url("/")
      expect(
        browser_root.locator(".new-home").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Hi friends!")],
        useInnerText: true,
      )
    end
  end

  context "when default theme uses a custom_homepage modifier" do
    before do
      theme.theme_modifier_set.custom_homepage = true
      theme.theme_modifier_set.save!
      theme.set_default!
    end

    it "shows empty state to regular users" do
      sign_in user
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".list-container").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".alert-info").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "shows empty state and notice to admins" do
      sign_in admin
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".list-container").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".alert-info").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    context "when the theme adds content to the [custom-homepage] connector" do
      let!(:basic_html_field) do
        Fabricate(
          :theme_field,
          theme: theme,
          type_id: ThemeField.types[:js],
          target_id: Theme.targets[:extra_js],
          name: "discourse/api-initializers/theme-initializer.gjs",
          value: <<~GJS,
            import { apiInitializer } from "discourse/lib/api";

            export default apiInitializer((api) => {
              api.renderInOutlet(
                "custom-homepage",
                <template>
                  <div class="new-home">Hi friends!</div>
                </template>
              );
            });
          GJS
        )
      end

      include_examples "a custom homepage"
    end

    context "when a theme component adds content to the [custom-homepage] connector" do
      let!(:component) { Fabricate(:theme, component: true) }
      let!(:component_html_field) do
        Fabricate(
          :theme_field,
          theme: component,
          type_id: ThemeField.types[:js],
          target_id: Theme.targets[:extra_js],
          name: "discourse/api-initializers/theme-initializer.gjs",
          value: <<~GJS,
            import { apiInitializer } from "discourse/lib/api";

            export default apiInitializer((api) => {
              api.renderInOutlet(
                "custom-homepage",
                <template>
                  <div class="new-home">Hi friends!</div>
                </template>
              );
            });
          GJS
        )
      end

      before { theme.add_relative_theme!(:child, component) }

      include_examples "a custom homepage"
    end
  end

  context "when a theme component uses the custom_homepage modifier" do
    let!(:component) { Fabricate(:theme, component: true) }
    let!(:component_html_field) do
      Fabricate(
        :theme_field,
        theme: component,
        type_id: ThemeField.types[:js],
        target_id: Theme.targets[:extra_js],
        name: "discourse/api-initializers/theme-initializer.gjs",
        value: <<~GJS,
          import { apiInitializer } from "discourse/lib/api";

          export default apiInitializer((api) => {
            api.renderInOutlet(
              "custom-homepage",
              <template>
                <div class="new-home">Hi friends!</div>
              </template>
            );
          });
        GJS
      )
    end

    before do
      component.theme_modifier_set.custom_homepage = true
      component.theme_modifier_set.save!
      theme.add_relative_theme!(:child, component)
      theme.set_default!
    end

    include_examples "a custom homepage"
  end
end
