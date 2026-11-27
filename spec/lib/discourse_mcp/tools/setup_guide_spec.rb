# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools::GetSetupGuide do
  fab!(:admin)
  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "Announcements") }
  fab!(:staff_category) { Fabricate(:private_category, group: Group[:staff], name: "Staff") }
  fab!(:welcome_topic) { Fabricate(:topic, title: "Welcome to our new community") }

  def request_context(user, scopes: DiscourseMcp.registry.scopes)
    context =
      instance_double(DiscourseMcp::RequestContext, guardian: user.guardian, scopes: scopes.to_set)
    allow(context).to receive(:has_scopes?) do |required|
      Array(required).all? { |scope| scopes.include?(scope.to_s) }
    end
    context
  end

  def call(user = admin, **context_options)
    described_class.call(arguments: {}, request_context: request_context(user, **context_options))
  end

  before do
    SiteSetting.staff_category_id = staff_category.id
    SiteSetting.welcome_topic_id = welcome_topic.id
  end

  it "returns the guide with links to this site" do
    result = call

    guide = result.dig(:structuredContent, :guide)
    expect(guide).to start_with("# Set up this Discourse community")
    expect(guide).to include("#{Discourse.base_url}/admin/config/logo")
    expect(guide).not_to include("{{base_url}}")
    expect(result[:content].first[:text]).to eq(guide)
  end

  it "links to each category's security settings" do
    subcategory = Fabricate(:category, parent_category: category, name: "Layouts")

    categories = call.dig(:structuredContent, :site, :categories)

    expect(categories).to include(
      include(
        id: category.id,
        security_url: "#{Discourse.base_url}/c/#{category.slug}/edit/security",
      ),
      include(
        id: subcategory.id,
        security_url: "#{Discourse.base_url}/c/#{category.slug}/#{subcategory.slug}/edit/security",
      ),
    )
  end

  it "describes the site as it is now" do
    SiteSetting.title = "Model Trains"
    SiteSetting.login_required = true

    site = call.dig(:structuredContent, :site)

    expect(site[:settings]).to include(title: "Model Trains", login_required: true)
    expect(site[:settings_at_default]).to include("site_description", "invite_only")
    expect(site[:settings_at_default]).not_to include("title", "login_required")
    expect(site[:categories]).to include(
      include(id: category.id, name: "Announcements", private: false, seeded: false),
      include(id: staff_category.id, private: true, seeded: true),
    )
    expect(site[:seeded_topics][:welcome]).to include(
      topic_id: welcome_topic.id,
      url: welcome_topic.url,
    )
    expect(JSON.parse(call[:content].last[:text]).dig("site", "settings", "title")).to eq(
      "Model Trains",
    )
  end

  it "leaves out what this connection can't read" do
    site = call(scopes: %w[mcp:profile:read mcp:site-settings:read]).dig(:structuredContent, :site)

    expect(site.keys).to contain_exactly(
      :url,
      :settings,
      :settings_at_default,
      :logo_uploaded,
      :tools,
    )
  end

  it "needs both content and category access to list categories" do
    site =
      call(scopes: %w[mcp:site-settings:read mcp:content:read mcp:themes:read]).dig(
        :structuredContent,
        :site,
      )

    expect(site).not_to have_key(:categories)
    expect(site[:seeded_topics]).to include(:welcome)
    expect(site).to include(:default_theme, :color_palettes)
  end

  it "lists only the tools this connection can use" do
    McpPrimitive.create!(kind: "tool", identifier: "discourse_get_setup_guide", enabled: true)
    McpPrimitive.create!(kind: "tool", identifier: "discourse_create_category", enabled: true)
    McpPrimitive.create!(kind: "tool", identifier: "discourse_search", enabled: false)

    tools =
      call(scopes: %w[mcp:profile:read mcp:site-settings:read]).dig(
        :structuredContent,
        :site,
        :tools,
      )

    expect(tools).to contain_exactly("discourse_get_setup_guide")
  end

  it "refuses users who aren't admins" do
    expect { call(user) }.to raise_error(Discourse::InvalidAccess)
  end

  describe "onboarding" do
    def connect_agent_logs
      UserHistory.where(
        action: UserHistory.actions[:admin_onboarding_step_completed],
        subject: "connect_agent",
      )
    end

    it "records the first time an agent uses the guide and tells the owner's browser" do
      SiteSetting.enable_site_owner_onboarding = true

      messages =
        MessageBus.track_publish(AdminOnboarding::STEP_COMPLETED_CHANNEL) { 2.times { call } }

      expect(connect_agent_logs.pluck(:acting_user_id)).to eq([admin.id])
      expect(messages.map(&:data)).to eq([{ step: "connect_agent" }])
      expect(messages.first.user_ids).to eq([admin.id])
    end

    it "leaves onboarding alone once it's over" do
      SiteSetting.enable_site_owner_onboarding = false

      call

      expect(connect_agent_logs).to be_empty
    end
  end

  it "only names tools that exist" do
    guide = call.dig(:structuredContent, :guide)
    named_tools = guide.scan(/\bdiscourse_[a-z_]+\b/).uniq

    expect(named_tools).to be_present
    named_tools.each { |name| expect(DiscourseMcp.registry.find(:tool, name)).to be_present }
  end
end
