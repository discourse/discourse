#frozen_string_literal: true

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

      expect(system_agent_classes).to contain_exactly(
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
