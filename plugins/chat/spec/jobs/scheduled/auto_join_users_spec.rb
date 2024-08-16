# frozen_string_literal: true

describe Jobs::Chat::AutoJoinUsers do
  subject(:job) { described_class.new }

  fab!(:channel) { Fabricate(:category_channel, auto_join_users: true) }
  fab!(:user) { Fabricate(:user, last_seen_at: 1.minute.ago, active: true) }
  fab!(:group)
  fab!(:user_without_chat) do
    user = Fabricate(:user)
    user.user_option.update!(chat_enabled: false)
    user
  end
  fab!(:stage_user) { Fabricate(:user, staged: true) }
  fab!(:suspended_user) { Fabricate(:user, suspended_till: 1.day.from_now) }
  fab!(:inactive_user) { Fabricate(:user, active: false) }
  fab!(:anonymous_user) { Fabricate(:anonymous) }

  before { Jobs.run_immediately! }

  it "is does not auto join users without permissions" do
    channel.category.read_restricted = true
    channel.category.set_permissions(group => :full)
    channel.category.save!

    job.execute({})

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership).to be_nil

    GroupUser.create!(group: group, user: user)

    job.execute({})

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership).to_not be_nil
  end

  it "works for simple workflows" do
    # this is just to avoid test fragility, we should always have negative users
    bot_id = (User.minimum(:id) - 1)
    bot_id = -1 if bot_id > 0
    _bot_user = Fabricate(:user, id: bot_id)

    membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(membership).to be_nil

    job.execute({})

    # should exclude bot / inactive / staged / suspended users
    # note category fabricator creates a user so we are stuck with that user in the channel
    expect(
      Chat::UserChatChannelMembership.where(chat_channel: channel).pluck(:user_id),
    ).to contain_exactly(user.id, channel.category.user.id)

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
