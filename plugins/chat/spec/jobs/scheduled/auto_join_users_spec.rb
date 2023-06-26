# frozen_string_literal: true

require "rails_helper"

describe Jobs::Chat::AutoJoinUsers do
  subject(:job) { described_class.new }

  it "works" do
    Jobs.run_immediately!
    channel = Fabricate(:category_channel, auto_join_users: true)
    user = Fabricate(:user, last_seen_at: 1.minute.ago, active: true)

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership).to be_nil

    job.execute({})

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership.following).to eq(true)
  end
end
