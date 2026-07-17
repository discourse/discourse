# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::DiscourseAdminAssistant do
  subject(:assistant) { described_class.new }

  fab!(:admin)
  fab!(:regular_user, :user)

  before { enable_current_plugin }

  it "combines Discourse knowledge, general administration, and site-setting tools" do
    expect(assistant.tools).to eq(
      [
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
        DiscourseAi::Agents::Tools::EditCategory,
        DiscourseAi::Agents::Tools::EditTags,
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
      "Every change requires human approval.",
    )
  end

  it "is registered as a system agent with a deterministic id" do
    expect(DiscourseAi::Agents::Agent.system_agents[described_class]).to eq(-39)
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
