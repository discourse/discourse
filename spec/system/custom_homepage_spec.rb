# frozen_string_literal: true

describe "Homepage", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }
  let(:discovery) { PageObjects::Pages::Discovery.new }
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

  context "when default theme uses a custom_homepage modifier" do
    before do
      theme.theme_modifier_set.custom_homepage = true
      theme.theme_modifier_set.save!
      theme.set_default!
    end

    it "shows the custom homepage from the theme on the homepage" do
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
