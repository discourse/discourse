# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260504211108_backfill_reviewable_ai_tool_action_scope",
        )

RSpec.describe BackfillReviewableAiToolActionScope do
  fab!(:private_group, :group)
  fab!(:private_category) { Fabricate(:private_category, group: private_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic) }
  fab!(:ai_agent)

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { enable_current_plugin }

  def create_unscoped_reviewable(post_id:)
    tool_action =
      AiToolAction.create!(
        tool_name: "close_topic",
        tool_parameters: {
          topic_id: private_topic.id,
        },
        ai_agent: ai_agent,
        bot_user_id: Discourse.system_user.id,
        post_id: post_id,
      )

    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: tool_action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
        payload: {
          agent_name: "Test Agent",
        },
      )

    reviewable.update_columns(topic_id: nil, category_id: nil)
    reviewable
  end

  it "backfills topic and category for reviewables whose target action has a post" do
    reviewable = create_unscoped_reviewable(post_id: private_post.id)

    described_class.new.up

    reviewable.reload
    expect(reviewable.topic_id).to eq(private_topic.id)
    expect(reviewable.category_id).to eq(private_category.id)
  end

  it "leaves topic and category nil when the target action has no post" do
    reviewable = create_unscoped_reviewable(post_id: nil)

    described_class.new.up

    reviewable.reload
    expect(reviewable.topic_id).to be_nil
    expect(reviewable.category_id).to be_nil
  end

  it "does not overwrite reviewables that are already scoped" do
    reviewable = create_unscoped_reviewable(post_id: private_post.id)
    other_topic = Fabricate(:topic)
    reviewable.update_columns(topic_id: other_topic.id, category_id: other_topic.category_id)

    described_class.new.up

    reviewable.reload
    expect(reviewable.topic_id).to eq(other_topic.id)
    expect(reviewable.category_id).to eq(other_topic.category_id)
  end
end
