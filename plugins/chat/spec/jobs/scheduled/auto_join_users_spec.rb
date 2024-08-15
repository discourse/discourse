# frozen_string_literal: true

describe Jobs::Chat::AutoJoinUsers do
  subject(:job) { described_class.new }

  before { Jobs.run_immediately! }

  it "works" do
    _staged_user = Fabricate(:user, staged: true)
    _suspended_user = Fabricate(:user, suspended_till: 1.day.from_now)
    _inactive_user = Fabricate(:user, active: false)

    # this is just to avoid test fragility, we should always have negative users
    bot_id = (User.minimum(:id) - 1)
    bot_id = -1 if bot_id > 0
    _bot_user = Fabricate(:user, id: bot_id)

    channel = Fabricate(:category_channel, auto_join_users: true)
    user = Fabricate(:user, last_seen_at: 1.minute.ago, active: true)

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership).to be_nil

    job.execute({})

    # should exclude bot / inactive / staged / suspended users
    expect(Chat::UserChatChannelMembership.where(chat_channel: channel).count).to eq(
      User.real.not_suspended.not_staged.where(active: true).count,
    )

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership.following).to eq(true)

    membership.update!(following: false)
    job.execute({})

    membership.reload
    expect(membership.following).to eq(false)

    channel = Fabricate(:category_channel, auto_join_users: false)
    job.execute({})

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)

    expect(membership).to be_nil
  end
end
