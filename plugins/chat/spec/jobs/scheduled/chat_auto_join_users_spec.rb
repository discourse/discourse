# frozen_string_literal: true

require "rails_helper"

describe Jobs::ChatAutoJoinUsers do
  it "works" do
    Jobs.run_immediately!
    channel = Fabricate(:category_channel, auto_join_users: true)
    user = Fabricate(:user, last_seen_at: 1.minute.ago, active: true)

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership).to be_nil

    subject.execute({})

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership.following).to eq(true)
  end
end
