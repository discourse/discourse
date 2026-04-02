#frozen_string_literal: true

module FakeExternalPlugin
  class FakeExternalTool < DiscourseAi::Agents::Tools::Tool
    def self.signature
      { name: "fake_external_tool", description: "A fake tool", parameters: [] }
    end

    def self.custom?
      true
    end

    def self.name
      "fake_external_tool"
    end

    def invoke
      { result: "ok" }
    end
  end
end

class FakeExternalAgent < DiscourseAi::Agents::Agent
  def tools
    [FakeExternalPlugin::FakeExternalTool]
  end

  def system_prompt
    "Test agent"
  end
end

class TestAgent < DiscourseAi::Agents::Agent
  def tools
    [
      DiscourseAi::Agents::Tools::ListTags,
      DiscourseAi::Agents::Tools::Search,
      DiscourseAi::Agents::Tools::Image,
    ]
  end

  def system_prompt
    <<~PROMPT
      {site_url}
      {site_title}
      {site_description}
      {participants}
      {time}
      {date}
      {resource_url}
      {inferred_concepts}
    PROMPT
  end
end

RSpec.describe DiscourseAi::Agents::Agent do
  let(:agent) { TestAgent.new }

  let(:topic_with_users) do
    topic = Topic.new
    topic.allowed_users = [User.new(username: "joe"), User.new(username: "jane")]
    topic
  end

  let(:resource_url) { "https://path-to-resource" }
  let(:inferred_concepts) { %w[bulbassaur charmander squirtle].join(", ") }

  let(:context) do
    DiscourseAi::Agents::BotContext.new(
      site_url: Discourse.base_url,
      site_title: "test site title",
      site_description: "test site description",
      time: Time.zone.now,
      participants: topic_with_users.allowed_users.map(&:username).join(", "),
      resource_url: resource_url,
      inferred_concepts: inferred_concepts,
    )
  end

  fab!(:admin)
  fab!(:user)
  fab!(:upload)

  before { enable_current_plugin }

  after do
    # we are rolling back transactions so we can create poison cache
    AiAgent.agent_cache.flush!
  end

  it "renders the system prompt" do
    freeze_time

    rendered = agent.craft_prompt(context)
    system_message = rendered.messages.first[:content]

    expect(system_message).to include(Discourse.base_url)
    expect(system_message).to include("test site title")
    expect(system_message).to include("test site description")
    expect(system_message).to include("joe, jane")
    expect(system_message).to include(Time.zone.now.to_s)
    expect(system_message).to include(resource_url)
    expect(system_message).to include(inferred_concepts)

    tools = rendered.tools

    expect(tools.find { |t| t.name == "search" }).to be_present
    expect(tools.find { |t| t.name == "tags" }).to be_present

    # needs to be configured so it is not available
    expect(tools.find { |t| t.name == "image" }).to be_nil
  end

  it "can parse string that are wrapped in quotes" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          search_query: "\"quoted search term\"",
        },
      )

    tool_instance =
      DiscourseAi::Agents::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(tool_instance.parameters[:search_query]).to eq("quoted search term")
  end

  it "enforces enums" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          status: "cow",
          foo: "bar",
        },
      )

    tool_instance =
      DiscourseAi::Agents::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(tool_instance.parameters.key?(:status)).to eq(false)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          status: "open",
          foo: "bar",
        },
      )

    tool_instance =
      DiscourseAi::Agents::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(tool_instance.parameters[:status]).to eq("open")
  end

  it "can coerce integers" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          search_query: "hello world",
          foo: "bar",
        },
      )

    search =
      DiscourseAi::Agents::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(search.parameters[:max_posts]).to eq(3)
    expect(search.parameters[:search_query]).to eq("hello world")
    expect(search.parameters.key?(:foo)).to eq(false)
  end

  describe "custom agents" do
    it "is able to find custom agents" do
      Group.refresh_automatic_groups!

      # define an ai agent everyone can see
      agent =
        AiAgent.create!(
          name: "zzzpun_bot",
          description: "you write puns",
          system_prompt: "you are pun bot",
          tools: ["Image"],
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        )

      custom_agent = DiscourseAi::Agents::Agent.all(user: user).last
      expect(custom_agent.name).to eq("zzzpun_bot")
      expect(custom_agent.description).to eq("you write puns")

      instance = custom_agent.new
      expect(instance.tools).to eq([DiscourseAi::Agents::Tools::Image])
      expect(instance.craft_prompt(context).messages.first[:content]).to eq("you are pun bot")

      # should update
      agent.update!(name: "zzzpun_bot2")
      custom_agent = DiscourseAi::Agents::Agent.all(user: user).last
      expect(custom_agent.name).to eq("zzzpun_bot2")

      # can be disabled
      agent.update!(enabled: false)
      last_agent = DiscourseAi::Agents::Agent.all(user: user).last
      expect(last_agent.name).not_to eq("zzzpun_bot2")

      agent.update!(enabled: true)
      # no groups have access
      agent.update!(allowed_group_ids: [])

      last_agent = DiscourseAi::Agents::Agent.all(user: user).last
      expect(last_agent.name).not_to eq("zzzpun_bot2")
    end
  end

  describe "available agents" do
    it "includes all agents by default" do
      Group.refresh_automatic_groups!

      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "abc123"

      # Note: Artist and Designer agents require custom image generation tools
      # configured via AiTool. Testing them would require creating tools within
      # the test transaction, which causes query isolation issues. They are tested
      # separately in their respective tool specs.
      # Filter to only system agents with specific classes (reject base Agent class)
      agents =
        DiscourseAi::Agents::Agent
          .all(user: user)
          .select(&:system)
          .map(&:superclass)
          .reject { |klass| klass == DiscourseAi::Agents::Agent }
      expect(agents).to include(
        DiscourseAi::Agents::General,
        DiscourseAi::Agents::Creative,
        DiscourseAi::Agents::DiscourseHelper,
        DiscourseAi::Agents::Discover,
        DiscourseAi::Agents::GithubHelper,
        DiscourseAi::Agents::Researcher,
        DiscourseAi::Agents::SettingsExplorer,
        DiscourseAi::Agents::SqlHelper,
      )

      # it should allow staff access to WebArtifactCreator
      admin_agents =
        DiscourseAi::Agents::Agent
          .all(user: admin)
          .select(&:system)
          .map(&:superclass)
          .reject { |klass| klass == DiscourseAi::Agents::Agent }
      expect(admin_agents).to include(
        DiscourseAi::Agents::General,
        DiscourseAi::Agents::Creative,
        DiscourseAi::Agents::DiscourseHelper,
        DiscourseAi::Agents::Discover,
        DiscourseAi::Agents::GithubHelper,
        DiscourseAi::Agents::Researcher,
        DiscourseAi::Agents::SettingsExplorer,
        DiscourseAi::Agents::SqlHelper,
        DiscourseAi::Agents::WebArtifactCreator,
      )

      # omits agents if key is missing
      SiteSetting.ai_google_custom_search_api_key = ""
      SiteSetting.ai_artifact_security = "disabled"

      # Filter to only system agents with specific agent classes (not the base Agent class)
      # The base Agent class appears for agents that don't have required tools available
      system_agent_classes =
        DiscourseAi::Agents::Agent
          .all(user: admin)
          .select(&:system)
          .map(&:superclass)
          .reject { |klass| klass == DiscourseAi::Agents::Agent }

      expect(system_agent_classes).to include(
        DiscourseAi::Agents::General,
        DiscourseAi::Agents::SqlHelper,
        DiscourseAi::Agents::SettingsExplorer,
        DiscourseAi::Agents::Creative,
        DiscourseAi::Agents::DiscourseHelper,
        DiscourseAi::Agents::Discover,
        DiscourseAi::Agents::GithubHelper,
      )

      AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General]).update!(
        enabled: false,
      )

      system_agent_classes_after_disable =
        DiscourseAi::Agents::Agent
          .all(user: user)
          .select(&:system)
          .map(&:superclass)
          .reject { |klass| klass == DiscourseAi::Agents::Agent }

      expect(system_agent_classes_after_disable).to contain_exactly(
        DiscourseAi::Agents::SqlHelper,
        DiscourseAi::Agents::SettingsExplorer,
        DiscourseAi::Agents::Creative,
        DiscourseAi::Agents::DiscourseHelper,
        DiscourseAi::Agents::Discover,
        DiscourseAi::Agents::GithubHelper,
      )
    end
  end

  describe ".sync_external_registry!" do
    fab!(:fake_plugin) do
      plugin = Plugin::Instance.new
      plugin.path = "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
      plugin
    end

    def register_fake_feature(module_name: :test_module, feature: :test_feature)
      DiscoursePluginRegistry.register_external_ai_feature(
        {
          module_name: module_name,
          feature: feature,
          agent_klass: FakeExternalAgent,
          enabled_by_setting: nil,
        },
        fake_plugin,
      )
    end

    def reset_external_registry!
      described_class.instance_variable_set(:@external_registry_signature, nil)
      described_class.instance_variable_set(:@system_agents, nil)
      described_class.instance_variable_set(:@system_agents_by_id, nil)
      described_class.instance_variable_set(:@external_tools_by_name, nil)
    end

    after do
      DiscoursePluginRegistry._raw_external_ai_features.reject! do |entry|
        entry[:value][:module_name] == :test_module
      end
      reset_external_registry!
    end

    it "adds the external agent to system_agents" do
      register_fake_feature

      expected_id = described_class.external_agent_id(FakeExternalAgent)
      expect(described_class.system_agents[FakeExternalAgent]).to eq(expected_id)
    end

    it "makes the external agent discoverable by ID" do
      register_fake_feature

      expected_id = described_class.external_agent_id(FakeExternalAgent)
      expect(described_class.system_agents_by_id[expected_id]).to eq(FakeExternalAgent)
    end

    it "registers external tools for name-based lookup" do
      register_fake_feature

      expect(described_class.external_tool_by_name("FakeExternalTool")).to eq(
        FakeExternalPlugin::FakeExternalTool,
      )
    end

    it "includes external tools in the agent's available_tools" do
      register_fake_feature

      instance = FakeExternalAgent.new
      tool_names = instance.available_tools.map { |t| t.signature[:name] }
      expect(tool_names).to include("fake_external_tool")
    end

    it "produces one agent entry when two features share the same agent_klass" do
      register_fake_feature(feature: :feature_one)
      register_fake_feature(feature: :feature_two)

      matching = described_class.system_agents.select { |klass, _| klass == FakeExternalAgent }
      expect(matching.size).to eq(1)
    end

    it "does not overwrite a builtin agent when registered as an external agent_klass" do
      builtin_id = described_class.system_agents[DiscourseAi::Agents::SqlHelper]

      DiscoursePluginRegistry.register_external_ai_feature(
        {
          module_name: :test_module,
          feature: :sql_feature,
          agent_klass: DiscourseAi::Agents::SqlHelper,
          enabled_by_setting: nil,
        },
        fake_plugin,
      )
      reset_external_registry!

      expect(described_class.system_agents[DiscourseAi::Agents::SqlHelper]).to eq(builtin_id)
    end

    it "keeps the external agent in system_agents even when the plugin is disabled" do
      register_fake_feature

      expect(described_class.system_agents).to have_key(FakeExternalAgent)

      fake_plugin.stubs(:enabled?).returns(false)
      reset_external_registry!

      expect(described_class.system_agents).to have_key(FakeExternalAgent)
    end
  end

  describe "#craft_prompt" do
    fab!(:vector_def, :embedding_definition)

    before do
      Group.refresh_automatic_groups!
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_enabled = true
    end

    let(:ai_agent) { DiscourseAi::Agents::Agent.all(user: user).first.new }

    let(:with_cc) do
      context.messages = [{ content: "Tell me the time", type: :user }]
      context
    end

    def prompt_tool_names(prompt)
      prompt.tools.map(&:name)
    end

    context "when a agent has no uploads" do
      it "doesn't expose the uploaded document search tool" do
        expect(prompt_tool_names(ai_agent.craft_prompt(with_cc))).not_to include(
          "search_uploaded_documents",
        )
      end
    end

    context "when a agent has RAG uploads" do
      before do
        stored_ai_agent = AiAgent.find(ai_agent.id)
        UploadReference.ensure_exist!(target: stored_ai_agent, upload_ids: [upload.id])
      end

      it "exposes uploaded documents as a tool instead of injecting snippets into the prompt" do
        prompt = ai_agent.craft_prompt(with_cc)

        expect(prompt_tool_names(prompt)).to include("search_uploaded_documents")
        expect(prompt.messages.first[:content]).to include("search_uploaded_documents")
        expect(prompt.messages.first[:content]).not_to include(
          "The following texts will give you additional guidance",
        )
      end

      it "finds the uploaded document search tool" do
        tool_call =
          DiscourseAi::Completions::ToolCall.new(
            name: "search_uploaded_documents",
            id: "call_uploaded_docs",
            parameters: {
              query: "time",
            },
          )

        tool = ai_agent.find_tool(tool_call, bot_user: nil, llm: nil, context: with_cc)

        expect(tool).to be_a(DiscourseAi::Agents::Tools::SearchUploadedDocuments)
        expect(tool.agent).to eq(ai_agent)
      end
    end

    context "when the agent has examples" do
      fab!(:examples_agent) do
        Fabricate(
          :ai_agent,
          examples: [["User message", "assistant response"]],
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        )
      end

      it "includes them before the context messages" do
        custom_agent = DiscourseAi::Agents::Agent.find_by(id: examples_agent.id, user: user).new

        post_system_prompt_msgs = custom_agent.craft_prompt(with_cc).messages.last(3)

        expect(post_system_prompt_msgs).to contain_exactly(
          { content: "User message", type: :user },
          { content: "assistant response", type: :model },
          { content: "Tell me the time", type: :user },
        )
      end
    end
  end
end
