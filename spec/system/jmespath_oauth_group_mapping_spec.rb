# frozen_string_literal: true

describe "JMESPath Oauth Group Mapping", type: :system do
  include OmniauthHelpers

  let(:signup_page) { PageObjects::Pages::Signup.new }

  fab!(:admin_group) { Fabricate(:group, name: "Administrators") }
  fab!(:engineers_group) { Fabricate(:group, name: "Engineers") }
  fab!(:disabled_rule_group) { Fabricate(:group, name: "DisabledRuleGroup") }
  fab!(:wildcard_group) { Fabricate(:group, name: "WildcardGroup") }
  fab!(:employees_group) { Fabricate(:group, name: "Employees") }

  before do
    OmniAuth.config.test_mode = true
    SiteSetting.enable_google_oauth2_logins = true
    SiteSetting.jmespath_group_mapping_enabled = true
  end

  after { reset_omniauth_config(:google_oauth2) }

  def mock_google_auth_with_groups(email:, domain:, groups: [])
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "test-uid-#{SecureRandom.hex(4)}",
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: "Test User"),
      extra: {
        raw_info: {
          email_verified: true,
          hd: domain,
        },
        raw_groups: groups,
      },
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
  end

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
      mock_google_auth_with_groups(email: "admin@company.com", domain: "company.com")

      visit("/")
      signup_page.open.click_social_button("google_oauth2")
      expect(signup_page).to be_open
      signup_page.click_create_account

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by(email: "engineers@company.com")
      expect(user).to be_present
      expect(user.groups.pluck(:name)).to contain_exactly("Engineers", "Employees", "WildcardGroup")
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

      visit("/")
      signup_page.open.click_social_button("google_oauth2")
      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user.reload
      expect(user.groups.pluck(:name)).to contain_exactly("Employees")
    end
  end

  context "when feature is disabled" do
    it "does not assign groups" do
      SiteSetting.jmespath_group_mapping_enabled = false

      rules = [
        {
          provider: "google_oauth2",
          expression: "extra.raw_info.hd == 'company.com'",
          groups: ["Employees"],
          enabled: true,
        },
      ]

      SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules)

      mock_google_auth_with_groups(email: "user@company.com", domain: "company.com")

      visit("/")
      signup_page.open.click_social_button("google_oauth2")
      expect(signup_page).to be_open
      signup_page.click_create_account

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by(email: "user@company.com")
      expect(user).to be_present
      expect(user.groups).to be_empty
    end
  end
end
