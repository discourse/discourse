# frozen_string_literal: true

require "rails_helper"

describe Jobs::Chat::UpdateUserCountsForChannels do
  fab!(:chat_channel_1) { Fabricate(:category_channel, user_count: 0) }
  fab!(:chat_channel_2) { Fabricate(:category_channel, user_count: 0) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }
  fab!(:user_4) { Fabricate(:user) }

  def create_memberships
    user_1.user_chat_channel_memberships.create!(chat_channel: chat_channel_1, following: true)
    user_1.user_chat_channel_memberships.create!(chat_channel: chat_channel_2, following: true)

    user_2.user_chat_channel_memberships.create!(chat_channel: chat_channel_1, following: true)
    user_2.user_chat_channel_memberships.create!(chat_channel: chat_channel_2, following: true)

    user_3.user_chat_channel_memberships.create!(chat_channel: chat_channel_1, following: false)
    user_3.user_chat_channel_memberships.create!(chat_channel: chat_channel_2, following: true)
  end

  it "sets the user_count correctly for each chat channel" do
    create_memberships

    Jobs::Chat::UpdateUserCountsForChannels.new.execute

    expect(chat_channel_1.reload.user_count).to eq(2)
    expect(chat_channel_2.reload.user_count).to eq(3)
  end

  it "does not count suspended, non-activated, nor staged users" do
    user_1.user_chat_channel_memberships.create!(chat_channel: chat_channel_1, following: true)
    user_2.user_chat_channel_memberships.create!(chat_channel: chat_channel_2, following: true)
    user_3.user_chat_channel_memberships.create!(chat_channel: chat_channel_2, following: true)
    user_4.user_chat_channel_memberships.create!(chat_channel: chat_channel_2, following: true)
    user_2.update(suspended_till: 3.weeks.from_now)
    user_3.update(staged: true)
    user_4.update(active: false)

    Jobs::Chat::UpdateUserCountsForChannels.new.execute

    expect(chat_channel_1.reload.user_count).to eq(1)
    expect(chat_channel_2.reload.user_count).to eq(0)
  end

  it "does not count archived, or read_only channels" do
    create_memberships

    chat_channel_1.update!(status: :archived)
    Jobs::Chat::UpdateUserCountsForChannels.new.execute
    expect(chat_channel_1.reload.user_count).to eq(0)

    chat_channel_1.update!(status: :read_only)
    Jobs::Chat::UpdateUserCountsForChannels.new.execute
    expect(chat_channel_1.reload.user_count).to eq(0)
  end
end
