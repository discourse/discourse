# frozen_string_literal: true

RSpec.describe Jobs::DeleteReplies do
  fab!(:admin)

  fab!(:topic)
  fab!(:topic_timer) do
    Fabricate(
      :topic_timer,
      status_type: TopicTimer.types[:delete_replies],
      duration_minutes: 2880,
      user: admin,
      topic: topic,
      execute_at: 2.days.from_now,
    )
  end

  before { 3.times { create_post(topic: topic) } }

  it "can delete replies of a topic" do
    SiteSetting.skip_auto_delete_reply_likes = 0

    freeze_time(2.days.from_now)

    expect { described_class.new.execute(topic_timer_id: topic_timer.id) }.to change {
      topic.posts.count
    }.by(-2)

    topic_timer.reload
    expect(topic_timer.execute_at).to eq_time(2.days.from_now)
  end

  it "does not delete posts with likes over the threshold" do
    SiteSetting.skip_auto_delete_reply_likes = 3

    freeze_time(2.days.from_now)

    topic.posts.last.update!(like_count: SiteSetting.skip_auto_delete_reply_likes + 1)

    expect { described_class.new.execute(topic_timer_id: topic_timer.id) }.to change {
      topic.posts.count
    }.by(-1)
  end

  it "trashes the timer if user lacks delete permissions" do
    user = Fabricate(:user)
    topic = Fabricate(:topic)

    3.times { create_post(topic:) }

    timer =
      Fabricate(
        :topic_timer,
        status_type: TopicTimer.types[:delete_replies],
        duration_minutes: 2880,
        user:,
        topic:,
        execute_at: 2.days.from_now,
      )

    freeze_time(2.days.from_now)

    expect { described_class.new.execute(topic_timer_id: timer.id) }.not_to change {
      topic.posts.count
    }
    expect(timer.reload.deleted_at).to be_present
  end

  it "allows category moderators to delete replies" do
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.skip_auto_delete_reply_likes = 0

    user = Fabricate(:user, trust_level: TrustLevel[4])
    Group.user_trust_level_change!(user.id, user.trust_level)

    category = Fabricate(:category)
    topic = Fabricate(:topic, category:)
    Fabricate(:category_moderation_group, category:, group: user.groups.first)

    3.times { create_post(topic:) }

    timer =
      Fabricate(
        :topic_timer,
        status_type: TopicTimer.types[:delete_replies],
        duration_minutes: 2880,
        user:,
        topic:,
        execute_at: 2.days.from_now,
      )

    freeze_time(2.days.from_now)

    expect { described_class.new.execute(topic_timer_id: timer.id) }.to change {
      topic.posts.count
    }.by(-2)
    expect(timer.reload.deleted_at).to be_nil
  end
end
