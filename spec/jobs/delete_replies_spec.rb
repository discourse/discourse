# frozen_string_literal: true

require 'rails_helper'

describe Jobs::DeleteReplies do
  fab!(:admin) { Fabricate(:admin) }

  fab!(:topic) { Fabricate(:topic) }
  fab!(:topic_timer) do
    Fabricate(:topic_timer, status_type: TopicTimer.types[:delete_replies], duration: 2, user: admin, topic: topic, execute_at: 2.days.from_now)
  end

  before do
    3.times { create_post(topic: topic) }
  end

  it "can delete replies of a topic" do
    freeze_time (2.days.from_now)

    expect {
      described_class.new.execute(topic_timer_id: topic_timer.id)
    }.to change { topic.posts.count }.by(-2)

    topic_timer.reload
    expect(topic_timer.execute_at).to eq_time(2.day.from_now)
  end
end
