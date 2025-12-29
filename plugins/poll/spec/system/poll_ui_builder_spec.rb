# frozen_string_literal: true

describe "Poll UI Builder" do
  it "loads when local-dates plugin is disabled" do
    SiteSetting.discourse_local_dates_enabled = false

    visit "/"

    expect(page).to have_css("#site-logo")
  end
end
