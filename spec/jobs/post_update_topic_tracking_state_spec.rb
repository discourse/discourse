# frozen_string_literal: true

RSpec.describe Jobs::PostUpdateTopicTrackingState do
  subject(:job) { described_class.new }

  fab!(:post) { Fabricate(:post) }

  it "should publish messages" do
    messages = MessageBus.track_publish { job.execute({ post_id: post.id }) }
    expect(messages.size).not_to eq(0)
  end

  it "should not publish messages for deleted topics" do
    post.topic.trash!
    messages = MessageBus.track_publish { job.execute({ post_id: post.id }) }
    expect(messages.size).to eq(0)
  end
end
