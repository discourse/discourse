# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::AdminAssistant do
  subject(:assistant) { described_class.new }

  fab!(:admin)
  fab!(:regular_user, :user)

  before { enable_current_plugin }

  it "combines Discourse knowledge, general administration, and site-setting tools" do
    expect(assistant.tools).to include(
      *[
        DiscourseAi::Agents::Tools::LoadDiscourseWebsitePage,
        DiscourseAi::Agents::Tools::DiscourseMetaSearch,
        DiscourseAi::Agents::Tools::ListCategories,
        DiscourseAi::Agents::Tools::FindCategory,
        DiscourseAi::Agents::Tools::ListTags,
        DiscourseAi::Agents::Tools::SettingContext,
        DiscourseAi::Agents::Tools::SearchSettings,
        DiscourseAi::Agents::Tools::SearchDiscourseNavigation,
        DiscourseAi::Agents::Tools::ReadSiteSetting,
        DiscourseAi::Agents::Tools::ChangeSiteSetting,
        DiscourseAi::Agents::Tools::ListUpcomingChanges,
        DiscourseAi::Agents::Tools::ListReviewables,
        DiscourseAi::Agents::Tools::CloseTopic,
        DiscourseAi::Agents::Tools::LockPost,
        DiscourseAi::Agents::Tools::UnlistTopic,
        DiscourseAi::Agents::Tools::DeleteTopic,
        DiscourseAi::Agents::Tools::EditPost,
        DiscourseAi::Agents::Tools::CreateCategory,
        DiscourseAi::Agents::Tools::EditCategory,
        DiscourseAi::Agents::Tools::SetCategoryPermissions,
        DiscourseAi::Agents::Tools::DeleteCategory,
        DiscourseAi::Agents::Tools::ChangeTopicCategory,
        DiscourseAi::Agents::Tools::CreateTag,
        DiscourseAi::Agents::Tools::EditTag,
        DiscourseAi::Agents::Tools::ChangeTopicTags,
        DiscourseAi::Agents::Tools::MovePosts,
        DiscourseAi::Agents::Tools::SuspendUser,
        DiscourseAi::Agents::Tools::SilenceUser,
        DiscourseAi::Agents::Tools::MarkAsSolved,
      ],
    )
  end

  it "requires an administrator request and approval before changing settings" do
    expect(assistant.system_prompt).to include(
      "Only change site settings, categories, tags, reviewable content, topics, posts, or users when an administrator explicitly asks you to do so.",
      "When an administrator explicitly requests a change and provides the required details, invoke the corresponding write tool before writing any response.",
      "If required details are missing, ask for them.",
      "Invoke a separate write tool call for every requested change, including repeated requests and multiple changes in the same message.",
      "Previous tool calls never apply to later requests.",
      "Only say that a change is pending approval when the write tool returned a pending approval result in the current turn.",
      "Changes you submit through write tools require human approval.",
      "Manual changes in the admin UI do not go through the assistant's approval queue.",
    )
  end

  it "requests succinct answers while preserving essential guidance" do
    prompt = assistant.craft_prompt(DiscourseAi::Agents::BotContext.new)

    expect(prompt.system_message_text).to include(
      "Be succinct and stingy with words.",
      "Aim for under 80 words unless the user requests detail or the task requires it.",
      "Keep essential warnings, permissions, approval status, and verified links.",
    )
  end

  it "grounds UI and side-effect guidance in evidence" do
    prompt = assistant.craft_prompt(DiscourseAi::Agents::BotContext.new)

    expect(prompt.system_message_text).to include(
      "Ground UI steps, permissions, and side effects in tool results or documentation.",
      "If exact UI details are unverified, describe the intended configuration instead of guessing labels.",
      "Dependencies indicate prerequisites, not settings or data that will be deleted.",
      "For private categories, explain group permissions rather than guessing visibility controls",
      "Staff means admins and moderators, not high-trust users.",
    )
  end

  it "prefers Workflows over deprecated Automation only after checking site access" do
    expect(assistant.system_prompt).to include(
      "Treat the Automation plugin as deprecated for new setups; recommend Workflows instead.",
      "not as a fallback when Workflows is unavailable",
      "Before recommending a plugin or giving setup steps, verify this site's access",
      "Installed code, enabled flags, or public documentation do not prove plan entitlement.",
    )
  end

  it "includes site-specific restrictions in the shared system prompt" do
    plugin = Plugin::Instance.new
    restriction = "Workflows is unavailable on this site."
    modifier = ->(prompt, _agent) { "#{prompt}\n#{restriction}" }
    DiscoursePluginRegistry.register_modifier(plugin, :admin_assistant_system_prompt, &modifier)

    prompt = assistant.craft_prompt(DiscourseAi::Agents::BotContext.new(user: admin))

    expect(prompt.system_message_text).to include(restriction, "You are the Admin Assistant")
  ensure
    if plugin && modifier
      DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_system_prompt, &modifier)
    end
  end

  it "is registered as a system agent with a deterministic id" do
    expect(DiscourseAi::Agents::Agent.system_agents[described_class]).to eq(-39)
  end

  it "stops tool chains while an action is pending approval" do
    expect(assistant.stop_chain_on_pending_approval?).to eq(true)
  end

  it "instructs the model to route requests to the appropriate source tool" do
    prompt = assistant.craft_prompt(DiscourseAi::Agents::BotContext.new)

    expect(prompt.system_message_text).to include(
      "For questions about public Discourse hosting plans and pricing, call `load_discourse_website_page` with `page_name` set to `pricing`",
      "For managing this site's hosting account, subscription, invoices, or billing, use `search_discourse_navigation`",
      "Never invent a path",
      "For general questions about Discourse, call `search_meta_discourse` twice before answering",
      "For questions about this site's configuration or content, use the relevant site and administration tools",
    )
    expect(prompt.tools.map(&:name)).to include(
      "load_discourse_website_page",
      "search_meta_discourse",
      "search_discourse_navigation",
    )
  end

  it "includes plugin and Upcoming Changes guidance in both PM and chat prompts" do
    topic = Fabricate(:private_message_topic, user: admin)
    channel = Fabricate(:direct_message_channel, users: [admin, Discourse.system_user])
    contexts = [
      DiscourseAi::Agents::BotContext.new(user: admin, topic: topic),
      DiscourseAi::Agents::BotContext.new(user: admin, channel_id: channel.id),
    ]

    contexts.each do |context|
      prompt = assistant.craft_prompt(context)

      expect(prompt.system_message_text).to include(
        "Plugins can be disabled via their enable site setting (false disables, true enables)",
        "call `list_upcoming_changes`",
        "never bypass hidden-setting restrictions with `change_site_setting`",
      )
      expect(prompt.tools.map(&:name)).to include("list_upcoming_changes")
    end
  end

  it "is only available to administrators" do
    load Rails.root.join("plugins/discourse-ai/db/fixtures/agents/603_ai_agents.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative

    expect(
      DiscourseAi::Agents::Agent.find_by(user: admin, name: described_class.name),
    ).to be_present
    expect(
      DiscourseAi::Agents::Agent.find_by(user: regular_user, name: described_class.name),
    ).to be_nil
    agent = AiAgent.find(-39)

    expect(agent.require_approval).to eq(true)
    expect(agent.tools.map(&:first)).to eq(assistant.tools.map { it.to_s.split("::").last })
  end
end
