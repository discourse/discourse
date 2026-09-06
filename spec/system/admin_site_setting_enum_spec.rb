# frozen_string_literal: true

describe "Admin site setting enum" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  fab!(:admin)

  before { sign_in(admin) }

  it "saves a string-valued enum and keeps the preview in sync" do
    settings_page.visit("tag_style")
    settings_page.select_enum_value("tag_style", "box")

    expect(settings_page.find_setting("tag_style")).to have_css(".preview .discourse-tag.box")

    settings_page.save_setting("tag_style")
    page.refresh

    expect(settings_page.enum_setting("tag_style").value).to eq("box")
  end

  it "round-trips an integer-valued enum" do
    settings_page.visit("hide_post_sensitivity")
    settings_page.select_enum_value("hide_post_sensitivity", "0")
    settings_page.save_setting("hide_post_sensitivity")
    page.refresh

    expect(settings_page.enum_setting("hide_post_sensitivity").value).to eq("0")
  end
end
