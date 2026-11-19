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
      name: "custom_homepage",
      value: true,
    )
  end

  def publish_homepage_layout(target_theme)
    target_theme.set_field(
      target: :common,
      name: "homepage-blocks",
      type: :block_layout,
      value: { schema_version: 1, layout: [{ block: "layout", args: { mode: "stack" } }] }.to_json,
    )
    target_theme.save!
  end

  it "routes / to the custom homepage when the default theme has the setting enabled" do
    publish_homepage_layout(Theme.find_default)
    get "/"

    expect(response.status).to eq(200)
    expect(controller.controller_name).to eq("home_page")
  end

  it "keeps the default homepage while the theme has no homepage layout" do
    get "/"

    expect(controller.controller_name).not_to eq("home_page")
  end

  it "prefers a user's own homepage preference over the theme setting" do
    user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("categories"))
    sign_in(user)

    get "/"

    expect(response.status).to eq(200)
    expect(controller.controller_name).to eq("categories")
  end
end
