# frozen_string_literal: true

describe "JMESPath Discourse Connect Group Mapping", type: :system do
  fab!(:admin_group) { Fabricate(:group, name: "Administrators") }
  fab!(:engineers_group) { Fabricate(:group, name: "Engineers") }
  fab!(:disabled_rule_group) { Fabricate(:group, name: "DisabledRuleGroup") }
  fab!(:wildcard_group) { Fabricate(:group, name: "WildcardGroup") }
  fab!(:employees_group) { Fabricate(:group, name: "Employees") }
  fab!(:user)

  let(:signup_page) { PageObjects::Pages::Signup.new }

  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let!(:sso_port) { setup_test_discourse_connect_server(user: user, sso_secret:) }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }
  before do
    SiteSetting.discourse_connect_url = sso_url
    SiteSetting.discourse_connect_secret = sso_secret
    SiteSetting.enable_discourse_connect = true
    SiteSetting.jmespath_group_mapping_enabled = true
    Jobs.run_immediately!
  end

  context "when user signs up with DiscourseConnect" do
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

    let!(:payload) do
      {
        external_id: "test123",
        email: "engineers@company.com",
        custom_fields: {
          department: "Engineering",
        },
      }
    end

    before { SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules) }

    it "assigns user to correct groups based on JMESPath rules" do
      visit("/login")

      sso, sig = build_discourse_connect_payload(data)

      visit "/session/sso_login", query: { sso: sso, sig: sig }

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by(email: "engineers@company.com")
      expect(user).to be_present
      expect(user.groups.pluck(:name)).to contain_exactly("Engineers", "Employees", "WildcardGroup")
    end
  end
end
