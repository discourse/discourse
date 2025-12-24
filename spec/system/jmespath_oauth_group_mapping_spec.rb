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

    it "creates user and assigns correct groups based on JMESPath rules" do
      mock_google_auth(email: "engineers@company.com")

      signup_page.open.click_social_button("google_oauth2")
      expect(signup_page).to be_open
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

      login_page.open.click_social_button("google_oauth2")

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

      signup_page.open.click_social_button("google_oauth2")
      expect(signup_page).to be_open
      signup_page.click_create_account

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("user@company.com")
      expect(user).to be_present
      expect(user.groups.where(automatic: false)).to be_empty
    end
  end

  describe "traditional OAuth provider groups with external IDs" do
    fab!(:engineering_group) { Fabricate(:group, name: "Engineering") }

    it "does not auto-link OAuth provider groups with external IDs" do
      # Simulate traditional Google OAuth groups with external Google IDs
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "test-uid-traditional",
        info: OmniAuth::AuthHash::InfoHash.new(email: "user@company.com", name: "Test User"),
        extra: {
          raw_info: {
            email_verified: true,
          },
          raw_groups: [
            {
              id: "google-group-id-12345", # External ID from Google
              name: "Engineering", # Same name as Discourse group, but different ID
            },
          ],
        },
      )

      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

      authenticator = Auth::GoogleOAuth2Authenticator.new
      allow(authenticator).to receive(:provides_groups?).and_return(true)
      allow(authenticator).to receive(:raw_groups).and_return(
        [{ id: "google-group-id-12345", name: "Engineering" }],
      )
      allow(Discourse).to receive(:enabled_authenticators).and_return([authenticator])

      signup_page.open.click_social_button("google_oauth2")
      expect(signup_page).to be_open
      signup_page.click_create_account

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("user@company.com")
      expect(user).to be_present

      expect(user.groups.where(automatic: false)).to be_empty

      associated_group =
        AssociatedGroup.find_by(
          provider_name: "google_oauth2",
          provider_id: "google-group-id-12345",
        )
      expect(associated_group).to be_present
      expect(associated_group.name).to eq("Engineering")

      linkage =
        GroupAssociatedGroup.find_by(
          group_id: engineering_group.id,
          associated_group_id: associated_group.id,
        )
      expect(linkage).to be_nil
    end
  end
end
