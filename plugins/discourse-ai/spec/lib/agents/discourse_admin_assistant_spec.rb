# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::DiscourseAdminAssistant do
  subject(:assistant) { described_class.new }

  fab!(:admin)
  fab!(:regular_user, :user)

  before { enable_current_plugin }

  it "combines Discourse knowledge, general administration, and site-setting tools" do
    expect(assistant.tools).to eq(
      [
        DiscourseAi::Agents::Tools::LoadDiscourseWebsitePage,
        DiscourseAi::Agents::Tools::DiscourseMetaSearch,
        DiscourseAi::Agents::Tools::ListCategories,
        DiscourseAi::Agents::Tools::ListTags,
        DiscourseAi::Agents::Tools::SettingContext,
        DiscourseAi::Agents::Tools::SearchSettings,
        DiscourseAi::Agents::Tools::ReadSiteSetting,
        DiscourseAi::Agents::Tools::ChangeSiteSetting,
        DiscourseAi::Agents::Tools::ListReviewables,
        DiscourseAi::Agents::Tools::CloseTopic,
        DiscourseAi::Agents::Tools::LockPost,
        DiscourseAi::Agents::Tools::UnlistTopic,
        DiscourseAi::Agents::Tools::DeleteTopic,
        DiscourseAi::Agents::Tools::EditPost,
        DiscourseAi::Agents::Tools::CreateCategory,
        DiscourseAi::Agents::Tools::EditCategory,
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
      "Every change requires human approval.",
    )
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
      "For questions about official Discourse hosting plans, pricing, or billing, call `load_discourse_website_page` with `page_name` set to `pricing`",
      "For general questions about Discourse, call `search_meta_discourse` twice before answering",
      "For questions about this site's configuration or content, use the relevant site and administration tools",
    )
    expect(prompt.tools.map(&:name)).to include(
      "load_discourse_website_page",
      "search_meta_discourse",
    )
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
