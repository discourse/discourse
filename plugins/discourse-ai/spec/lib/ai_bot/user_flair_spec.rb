# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::UserFlair do
  fab!(:bot_user) { Fabricate(:user, id: -4000) }

  before { enable_current_plugin }

  it "assigns flair to users attached to an AI agent" do
    agent = Fabricate(:ai_agent)

    agent.update!(user: bot_user)

    group = Group.find_by(name: described_class::GROUP_NAME)
    expect(bot_user.reload.flair_group_id).to eq(group.id)
    expect(group.flair_url).to eq(described_class::FLAIR_ICON)
    expect(group.users).to contain_exactly(bot_user)
  end

  it "backfills flair for existing AI users" do
    agent = Fabricate(:ai_agent)
    agent.update_column(:user_id, bot_user.id)

    described_class.sync_all!

    group = Group.find_by(name: described_class::GROUP_NAME)
    expect(bot_user.reload.flair_group_id).to eq(group.id)
    expect(group.users).to contain_exactly(bot_user)
  end

  it "backfills flair for users attached to an LLM model" do
    model = Fabricate(:llm_model)
    model.update_column(:user_id, bot_user.id)

    described_class.sync_all!

    group = Group.find_by(name: described_class::GROUP_NAME)
    expect(bot_user.reload.flair_group_id).to eq(group.id)
    expect(group.users).to contain_exactly(bot_user)
  end

  it "updates the flair icon on an existing AI users group" do
    agent = Fabricate(:ai_agent, user: bot_user)
    group = Group.find_by(name: described_class::GROUP_NAME)
    group.update!(flair_icon: "robot")

    described_class.sync_all!

    expect(group.reload.flair_icon).to eq(described_class::FLAIR_ICON)
  end

  it "removes flair when a user is no longer attached to an AI model" do
    agent = Fabricate(:ai_agent, user: bot_user)
    group = Group.find_by(name: described_class::GROUP_NAME)

    agent.update!(user: nil)

    expect(bot_user.reload.flair_group_id).to be_nil
    expect(group.reload.users).not_to include(bot_user)
  end
end
