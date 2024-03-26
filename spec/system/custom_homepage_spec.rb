# frozen_string_literal: true

describe "Homepage", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }
  let(:discovery) { PageObjects::Pages::Discovery.new }

  before do
    # A workaround to avoid the global notice from interfering with the tests
    # It is coming from the ensure_login_hint.rb initializer and it gets
    # evaluated before the tests run (and it wrongly counts 0 admins defined)
    SiteSetting.global_notice = nil
  end

  it "by default shows a list of topics" do
    visit "/"
    expect(discovery.topic_list).to have_topics(count: 5)
  end

  context "when experimental_custom_homepage is enabled" do
    before { SiteSetting.experimental_custom_homepage = true }

    it "shows empty state to anonymous" do
      visit "/"

      expect(page).not_to have_css(".alert-info")
      expect(page).not_to have_css(".list-container")
    end

    it "shows empty state to regular users" do
      sign_in user
      visit "/"

      expect(page).not_to have_css(".alert-info")
      expect(page).not_to have_css(".list-container")
    end

    it "shows empty state and a message to admins" do
      sign_in admin
      visit "/"

      expect(page).not_to have_css(".list-container")
      expect(page).to have_css(".alert-info")
    end

    context "when theme extends the [custom-homepage] plugin outlet" do
      let!(:theme) { Fabricate(:theme) }
      let!(:basic_html_field) do
        Fabricate(
          :theme_field,
          theme: theme,
          type_id: ThemeField.types[:html],
          target_id: Theme.targets[:common],
          name: "head_tag",
          value: <<~HTML,
            <script type="text/x-handlebars" data-template-name="/connectors/custom-homepage/new-home">
              Hi friends!
            </script>
          HTML
        )
      end

      before { SiteSetting.default_theme_id = theme.id }

      it "shows the custom content from the theme on the homepage" do
        visit "/"

        expect(page).to have_css(".new-home", text: "Hi friends!")
        expect(page).not_to have_css(".list-container")

        find("#sidebar-section-content-community .sidebar-section-link:first-child").click
        expect(page).to have_css(".list-container")

        find("#site-logo").click

        expect(page).not_to have_css(".list-container")
        # ensure clicking on logo brings user back to the custom homepage
        expect(page).to have_css(".new-home", text: "Hi friends!")
      end

      it "respects the user's homepage choice" do
        visit "/"

        expect(page).not_to have_css(".list-container")
        expect(page).to have_css(".new-home", text: "Hi friends!")

        sign_in user
        # top page ID in UserOption::HOMEPAGES = 5
        user.user_option.update!(homepage_id: 5)

        visit "/"

        expect(page).to have_css(".navigation-container .top.active", text: "Top")
        expect(page).to have_css(".top-lists")
        expect(page).not_to have_css(".new-home", text: "Hi friends!")
      end
    end
  end
end
