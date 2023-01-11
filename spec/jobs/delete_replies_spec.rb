# frozen_string_literal: true

RSpec.describe Jobs::DeleteReplies do
  fab!(:admin) { Fabricate(:admin) }

  fab!(:topic) { Fabricate(:topic) }
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

    freeze_time (2.days.from_now)

    expect { described_class.new.execute(topic_timer_id: topic_timer.id) }.to change {
      topic.posts.count
    }.by(-2)

    topic_timer.reload
    expect(topic_timer.execute_at).to eq_time(2.day.from_now)
  end

  it "does not delete posts with likes over the threshold" do
    SiteSetting.skip_auto_delete_reply_likes = 3

    freeze_time (2.days.from_now)

    topic.posts.last.update!(like_count: SiteSetting.skip_auto_delete_reply_likes + 1)

    expect { described_class.new.execute(topic_timer_id: topic_timer.id) }.to change {
      topic.posts.count
    }.by(-1)
  end
end
