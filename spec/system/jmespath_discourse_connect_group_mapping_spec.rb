# frozen_string_literal: true

describe "JMESPath Discourse Connect Group Mapping", type: :system do
  include DiscourseConnectHelpers

  fab!(:admin_group) { Fabricate(:group, name: "Administrators") }
  fab!(:engineers_group) { Fabricate(:group, name: "Engineers") }
  fab!(:disabled_rule_group) { Fabricate(:group, name: "DisabledRuleGroup") }
  fab!(:wildcard_group) { Fabricate(:group, name: "WildcardGroup") }
  fab!(:employees_group) { Fabricate(:group, name: "Employees") }
  fab!(:user)

  fab!(:user) { Fabricate(:user, email: "engineers@company.com") }

  let(:signup_page) { PageObjects::Pages::Signup.new }

  let(:sso_secret) { SecureRandom.alphanumeric(32) }

  let(:new_user_sso_response_data) do
    {
      external_id: "test123",
      email: "engineers@company.com",
      username: "engineer_user",
      custom_fields: {
        department: "Engineering",
      },
    }
  end

  let(:existing_user_sso_response_data) do
    {
      external_id: "test3456",
      email: user.email,
      username: user.username,
      custom_fields: {
        department: "Engineering",
      },
    }
  end

  let!(:rules) do
    [
      {
        provider: "google_oauth2",
        expression: "contains(email, 'admins@company.com')",
        groups: ["Administrators"],
        enabled: true,
      },
      {
        provider: Auth::JmesPathGroupExtractor::DISCOURSE_CONNECT,
        expression: "contains(email, 'admins@company.com')",
        groups: ["Administrators"],
        enabled: true,
      },
      {
        provider: Auth::JmesPathGroupExtractor::DISCOURSE_CONNECT,
        expression: "contains(custom_fields.department, 'Engineering')",
        groups: %w[Engineers Employees],
        enabled: true,
      },
      {
        provider: "*",
        expression: "ends_with(email, '@company.com')",
        groups: ["WildcardGroup"],
        enabled: true,
      },
      {
        provider: Auth::JmesPathGroupExtractor::DISCOURSE_CONNECT,
        expression: "contains(email, 'engineers@company.com')",
        groups: %w[DisabledRuleGroup],
        enabled: false,
      },
    ]
  end

  before do
    SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules)
    SiteSetting.jmespath_group_mapping_enabled = true
    Jobs.run_immediately!
  end

  context "when user signs up with DiscourseConnect" do
    let!(:sso_port) do
      setup_test_discourse_connect_server(sso_secret:, response_data: new_user_sso_response_data)
    end
    let(:sso_url) { "http://localhost:#{sso_port}/sso" }

    before do
      SiteSetting.discourse_connect_url = sso_url
      SiteSetting.discourse_connect_secret = sso_secret
      SiteSetting.enable_discourse_connect = true
    end

    it "assigns user to correct groups based on JMESPath rules" do
      visit("/login")

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      created_user = User.find_by_email("engineers@company.com")
      expect(created_user).to be_present
      expect(created_user.groups.pluck(:name)).to contain_exactly(
        "Engineers",
        "Employees",
        "WildcardGroup",
      )
    end
  end

  context "when existing user logs in" do
    before do
      SiteSetting.discourse_connect_url = sso_url
      SiteSetting.discourse_connect_secret = sso_secret
      SiteSetting.enable_discourse_connect = true
    end

    let!(:sso_port) do
      setup_test_discourse_connect_server(
        sso_secret:,
        response_data: existing_user_sso_response_data,
      )
    end
    let(:sso_url) { "http://localhost:#{sso_port}/sso" }

    it "assigns user to correct groups based on JMESPath rules" do
      visit("/login")

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      created_user = User.find_by_email("engineers@company.com")
      expect(created_user).to be_present
      expect(created_user.groups.pluck(:name)).to contain_exactly(
        "Engineers",
        "Employees",
        "WildcardGroup",
      )
    end
  end
end
