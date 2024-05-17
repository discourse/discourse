# frozen_string_literal: true

describe "Homepage", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }
  let(:discovery) { PageObjects::Pages::Discovery.new }
  fab!(:theme)

  before do
    # A workaround to avoid the global notice from interfering with the tests
    # It is coming from the ensure_login_hint.rb initializer and it gets
    # evaluated before the tests run (and it wrongly counts 0 admins defined)
    SiteSetting.global_notice = nil
  end

  it "shows a list of topics by default" do
    visit "/"
    expect(discovery.topic_list).to have_topics(count: 5)
  end

  it "allows users to pick their homepage" do
    sign_in user
    visit "/"

    expect(page).to have_css(".navigation-container .latest.active", text: "Latest")

    visit "u/#{user.username}/preferences/interface"

    homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
    homepage_picker.expand
    homepage_picker.select_row_by_name("Top")
    page.find(".btn-primary.save-changes").click

    # Wait for the save to complete
    find(".btn-primary.save-changes:not([disabled])", wait: 5)

    visit "/"

    expect(page).to have_css(".navigation-container .top.active", text: "Top")
    expect(page).to have_css(".top-lists")
  end

  it "defaults to first top_menu item as anonymous homepage" do
    SiteSetting.top_menu = "categories|latest|new|unread"
    visit "/"

    expect(page).to have_css(".navigation-container .categories.active", text: "Categories")

    sign_in user
    visit "/"

    expect(page).to have_css(".navigation-container .categories.active", text: "Categories")
  end

  context "when default theme uses a custom_homepage modifier" do
    before do
      theme.theme_modifier_set.custom_homepage = true
      theme.theme_modifier_set.save!
      theme.set_default!
    end

    it "shows empty state to regular users" do
      sign_in user
      visit "/"

      expect(page).to have_no_css(".list-container")
      expect(page).to have_no_css(".alert-info")
    end

    it "shows empty state and notice to admins" do
      sign_in admin
      visit "/"

      expect(page).to have_no_css(".list-container")
      expect(page).to have_css(".alert-info")
    end

    shared_examples "a custom homepage" do
      it "shows the custom homepage component" do
        visit "/"

        expect(page).to have_css(".new-home", text: "Hi friends!")
        expect(page).to have_no_css(".list-container")

        find("#sidebar-section-content-community li:first-child").click
        expect(page).to have_css(".list-container")

        find("#site-logo").click

        expect(page).to have_no_css(".list-container")
        # ensure clicking on logo brings user back to the custom homepage
        expect(page).to have_css(".new-home", text: "Hi friends!")
      end

      it "respects the user's homepage choice" do
        visit "/"

        expect(page).not_to have_css(".list-container")
        expect(page).to have_css(".new-home", text: "Hi friends!")

        sign_in user

        visit "/u/#{user.username}/preferences/interface"

        homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
        homepage_picker.expand
        # user overrides theme custom homepage
        homepage_picker.select_row_by_name("Top")
        page.find(".btn-primary.save-changes").click

        # Wait for the save to complete
        find(".btn-primary.save-changes:not([disabled])", wait: 5)

        find("#site-logo").click

        expect(page).to have_css(".navigation-container .top.active", text: "Top")
        expect(page).to have_css(".top-lists")

        visit "/u/#{user.username}/preferences/interface"

        homepage_picker = PageObjects::Components::SelectKit.new("#home-selector")
        homepage_picker.expand
        # user selects theme custom homepage again
        homepage_picker.select_row_by_name("(default)")
        page.find(".btn-primary.save-changes").click

        # Wait for the save to complete
        find(".btn-primary.save-changes:not([disabled])", wait: 5)
        find("#site-logo").click

        expect(page).not_to have_css(".list-container")
        expect(page).to have_css(".new-home", text: "Hi friends!")
      end
    end

    context "when the theme adds content to the [custom-homepage] connector" do
      let!(:basic_html_field) do
        Fabricate(
          :theme_field,
          theme: theme,
          type_id: ThemeField.types[:html],
          target_id: Theme.targets[:common],
          name: "head_tag",
          value: <<~HTML,
            <script type="text/x-handlebars" data-template-name="/connectors/custom-homepage/new-home">
              <div class="new-home">Hi friends!</div>
            </script>
          HTML
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
          type_id: ThemeField.types[:html],
          target_id: Theme.targets[:common],
          name: "head_tag",
          value: <<~HTML,
            <script type="text/x-handlebars" data-template-name="/connectors/custom-homepage/new-home">
              <div class="new-home">Hi friends!</div>
            </script>
          HTML
        )
      end

      before { theme.add_relative_theme!(:child, component) }

      include_examples "a custom homepage"
    end
  end
end
