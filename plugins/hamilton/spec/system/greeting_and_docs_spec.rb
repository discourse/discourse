# frozen_string_literal: true

RSpec.describe "Hamilton greeting and documentation" do
  fab!(:admin)

  let(:hamilton) { PageObjects::Pages::Hamilton.new }
  let(:settings) { PageObjects::Pages::AdminSiteSettings.new }

  before { enable_current_plugin }

  it "lets visitors read the greeting, README, and guide" do
    hamilton.visit
    expect(hamilton).to have_greeting("world")

    hamilton.open_docs
    expect(page).to have_current_path("/hamilton/docs")
    expect(hamilton).to have_readme

    page.refresh
    expect(hamilton).to have_readme

    hamilton.open_guide
    expect(hamilton).to have_guide
  end

  it "lets administrators save a greeting and shows HTML as plain text" do
    sign_in(admin)
    visit "/admin/plugins/hamilton/settings"
    expect(settings).to have_setting("hamilton_greeting")

    settings.fill_setting("hamilton_greeting", "mcwumbly <b>hello</b>")
    settings.save_setting("hamilton_greeting")
    expect(settings).to have_overridden_setting("hamilton_greeting", value: "mcwumbly <b>hello</b>")

    page.refresh
    expect(settings).to have_overridden_setting("hamilton_greeting", value: "mcwumbly <b>hello</b>")

    hamilton.visit
    expect(hamilton).to have_greeting("mcwumbly <b>hello</b>")
  end

  it "lets anonymous visitors read documentation on a private site" do
    SiteSetting.login_required = true

    visit "/hamilton/docs"
    expect(hamilton).to have_readme
  end
end
