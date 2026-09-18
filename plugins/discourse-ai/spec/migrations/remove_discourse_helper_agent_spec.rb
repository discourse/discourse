# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/post_migrate/20260824192615_remove_discourse_helper_agent.rb",
        )

RSpec.describe RemoveDiscourseHelperAgent do
  subject(:migrate) { described_class.new.up }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "removes the agent while preserving its user and personal messages" do
    helper = AiAgent.find(described_class::DISCOURSE_HELPER_AGENT_ID)
    helper_user = helper.user || helper.create_user!
    parent_agent = Fabricate(:ai_agent, subagent_ids: [helper.id])
    pm_user = Fabricate(:user)
    topic = Fabricate(:private_message_topic, user: pm_user, recipient: helper_user)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = helper.id
    topic.save_custom_fields
    bot_post = Fabricate(:post, topic: topic, user: helper_user)

    migrate

    expect(AiAgent.exists?(helper.id)).to eq(false)
    expect(parent_agent.reload.subagent_ids).to eq([])
    expect(helper_user.reload).to be_present
    expect(topic.reload).to be_present
    expect(bot_post.reload.user).to eq(helper_user)
    expect(topic.custom_fields).to include(
      DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD => helper.id.to_s,
      "ai_agent" => helper.name,
    )
  end
end
