# frozen_string_literal: true

RSpec.describe TopicTrackingStateSerializer do
  fab!(:user)
  fab!(:post) { create_post }

  it "serializes topic tracking state report correctly for a normal user" do
    report = TopicTrackingState.report(user)
    serialized = described_class.new(report, scope: Guardian.new(user), root: false).as_json

    expect(serialized[:data].length).to eq(1)
    expect(serialized[:data].first[:topic_id]).to eq(post.topic_id)

    expect(serialized[:meta].keys).to contain_exactly(
      TopicTrackingState::LATEST_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::RECOVER_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::DELETE_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::DESTROY_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::NEW_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::UNREAD_MESSAGE_BUS_CHANNEL,
      TopicTrackingState.unread_channel_key(user.id),
    )
  end
end
