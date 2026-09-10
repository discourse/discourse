# frozen_string_literal: true

RSpec.describe HomepageHelper do
  fab!(:theme)
  fab!(:other_theme, :theme)

  before { SiteSetting.wireframe_enabled = true }

  def request_resolved_to(theme_id, headers = {})
    request = ActionDispatch::TestRequest.create(headers)
    request.env[:resolved_theme_id] = theme_id
    request
  end

  def enable_for(target_theme)
    Fabricate(
      :theme_site_setting_with_service,
      theme: target_theme,
      name: "wireframe_custom_homepage",
      value: true,
    )
  end

  it "returns the default homepage when the setting is off" do
    expect(HomepageHelper.resolve(request_resolved_to(theme.id))).to eq("latest")
  end

  it "returns custom only for requests resolved to a theme with the setting enabled" do
    enable_for(theme)

    expect(HomepageHelper.resolve(request_resolved_to(theme.id))).to eq("custom")
    expect(HomepageHelper.resolve(request_resolved_to(other_theme.id))).to eq("latest")
  end

  it "returns the configured crawler route for crawler requests" do
    enable_for(theme)
    SiteSetting.custom_homepage_crawler_route = "categories"

    request = request_resolved_to(theme.id, "HTTP_USER_AGENT" => "Googlebot")

    expect(HomepageHelper.resolve(request)).to eq("categories")
  end

  it "returns the default homepage when the plugin is disabled" do
    enable_for(theme)
    SiteSetting.wireframe_enabled = false

    expect(HomepageHelper.resolve(request_resolved_to(theme.id))).to eq("latest")
  end

  it "returns the default homepage when no theme can be resolved" do
    enable_for(theme)

    expect(HomepageHelper.resolve(request_resolved_to(nil))).to eq("latest")
    expect(HomepageHelper.resolve).to eq("latest")
  end

  it "returns blank for anonymous users when login is required" do
    enable_for(theme)
    SiteSetting.login_required = true

    expect(HomepageHelper.resolve(request_resolved_to(theme.id))).to eq("blank")
  end

  it "ignores the setting when it was written to a component of the resolved theme" do
    component = Fabricate(:theme, component: true)
    theme.add_relative_theme!(:child, component)
    enable_for(component)

    expect(HomepageHelper.resolve(request_resolved_to(theme.id))).to eq("latest")
  end
end
