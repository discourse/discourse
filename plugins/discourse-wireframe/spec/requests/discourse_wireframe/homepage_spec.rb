# frozen_string_literal: true

RSpec.describe "Wireframe custom homepage routing" do
  fab!(:user)

  before do
    SiteSetting.wireframe_enabled = true
    # Otherwise every request to `/` routes to finish_installation in the bare
    # test database (no active admin exists yet).
    SiteSetting.has_login_hint = false
    Fabricate(
      :theme_site_setting_with_service,
      theme: Theme.find_default,
      name: "wireframe_custom_homepage",
      value: true,
    )
  end

  it "routes / to the custom homepage when the default theme has the setting enabled" do
    get "/"

    expect(response.status).to eq(200)
    expect(controller.controller_name).to eq("home_page")
  end

  it "prefers a user's own homepage preference over the theme setting" do
    user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("categories"))
    sign_in(user)

    get "/"

    expect(response.status).to eq(200)
    expect(controller.controller_name).to eq("categories")
  end
end
