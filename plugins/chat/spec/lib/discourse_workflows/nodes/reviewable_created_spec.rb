# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ReviewableCreated::V1 do
  fab!(:reviewable, :chat_reviewable_message)

  it "exposes the chat channel when the flagged message was deleted", :aggregate_failures do
    channel_id = reviewable.target.chat_channel_id
    reviewable.target.trash!

    output = described_class.new(Reviewable.find(reviewable.id)).output

    expect(output[:reviewable][:chat_channel_id]).to eq(channel_id)
    expect(output).to match_node_output_schema(described_class)
  end
end
