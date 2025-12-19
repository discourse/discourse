# frozen_string_literal: true

describe "JMESPath Oauth Group Mapping", type: :system do
  include OmniauthHelpers

  let(:signup_page) { PageObjects::Pages::Signup.new }
  let(:login_page) { PageObjects::Pages::Login.new }
  fab!(:admin_group) { Fabricate(:group, name: "Administrators") }
  fab!(:engineers_group) { Fabricate(:group, name: "Engineers") }
  fab!(:disabled_rule_group) { Fabricate(:group, name: "DisabledRuleGroup") }
  fab!(:wildcard_group) { Fabricate(:group, name: "WildcardGroup") }
  fab!(:employees_group) { Fabricate(:group, name: "Employees") }

  let(:signup_form) { PageObjects::Pages::SignUp.new }

  before do
    OmniAuth.config.test_mode = true
    SiteSetting.enable_google_oauth2_logins = true
    SiteSetting.jmespath_group_mapping_enabled = true
  end

  after { reset_omniauth_config(:google_oauth2) }

  context "when user signs up with OAuth" do
    let!(:rules) do
      [
        {
          provider: "google_oauth2",
          expression: "contains(info.email, 'admins@company.com')",
          groups: ["Administrators"],
          enabled: true,
        },
        {
          provider: "google_oauth2",
          expression: "contains(info.email, 'engineers@company.com')",
          groups: %w[Engineers Employees],
          enabled: true,
        },
        {
          provider: "*",
          expression: "ends_with(info.email, '@company.com')",
          groups: ["WildcardGroup"],
          enabled: true,
        },
        {
          provider: "google_oauth2",
          expression: "contains(info.email, 'engineers@company.com')",
          groups: %w[DisabledRuleGroup],
          enabled: false,
        },
      ]
    end

    before { SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules) }

    it "assigns user to correct groups based on JMESPath rules" do
      mock_google_auth(email: "engineers@company.com")
      visit("/login")
      signup_page.click_create_account

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("engineers@company.com")
      expect(user).to be_present
      expect(user.groups.where(automatic: false).pluck(:name)).to contain_exactly(
        "Engineers",
        "Employees",
        "WildcardGroup",
      )
    end
  end

  context "when existing user logs in with OAuth" do
    fab!(:user) { Fabricate(:user, email: "existing@company.com") }
    let!(:rules) do
      [
        {
          provider: "google_oauth2",
          expression: "extra.raw_info.hd == 'company.com'",
          groups: ["Employees"],
          enabled: true,
        },
      ]
    end

    before { SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules) }

    it "adds user to groups on subsequent logins" do
      UserAssociatedAccount.create!(
        provider_name: "google_oauth2",
        user_id: user.id,
        provider_uid: "test-uid-existing",
      )

      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "test-uid-existing",
        info: OmniAuth::AuthHash::InfoHash.new(email: user.email, name: user.name),
        extra: {
          raw_info: {
            email_verified: true,
            hd: "company.com",
          },
          raw_groups: [],
        },
      )

      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

      visit("/login")

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user.reload
      expect(user.groups.where(automatic: false).pluck(:name)).to contain_exactly("Employees")
    end
  end

  context "when feature is disabled" do
    let(:rules) do
      [
        {
          provider: "google_oauth2",
          expression: "extra.raw_info.hd == 'company.com'",
          groups: ["Employees"],
          enabled: true,
        },
      ]
    end

    before { SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules) }

    it "does not assign groups" do
      SiteSetting.jmespath_group_mapping_enabled = false

      mock_google_auth(email: "user@company.com")

      visit("/login")
      signup_page.click_create_account

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("user@company.com")
      expect(user).to be_present
      expect(user.groups.where(automatic: false)).to be_empty
    end
  end
end
