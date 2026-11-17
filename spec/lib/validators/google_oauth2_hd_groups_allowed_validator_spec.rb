# frozen_string_literal: true

RSpec.describe GoogleOauth2HdGroupsAllowedValidator do
  subject(:validator) { described_class.new }

  it "allows a blank allowlist without group lookup settings" do
    expect(validator.valid_value?("")).to eq(true)
  end

  it "allows an allowlist when all group lookup settings are configured" do
    SiteSetting.google_oauth2_hd = "domain.com"
    SiteSetting.google_oauth2_hd_groups_service_account_admin_email = "admin@domain.com"
    SiteSetting.google_oauth2_hd_groups_service_account_json = "{}"

    expect(validator.valid_value?("group@domain.com")).to eq(true)
  end

  it "rejects an allowlist when a group lookup setting is missing" do
    SiteSetting.google_oauth2_hd = "domain.com"
    SiteSetting.google_oauth2_hd_groups_service_account_admin_email = "admin@domain.com"

    expect(validator.valid_value?("group@domain.com")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.google_oauth2_hd_groups_allowed"),
    )
  end
end
