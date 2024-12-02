# frozen_string_literal: true

describe Jobs::Chat::AutoJoinUsers do
  subject(:job) { described_class.new }

  fab!(:channel) { Fabricate(:category_channel, auto_join_users: true) }
  fab!(:user) { Fabricate(:user, last_seen_at: 1.minute.ago, trust_level: 1) }
  fab!(:group)
  fab!(:user_without_chat) do
    user = Fabricate(:user)
    user.user_option.update!(chat_enabled: false)
    user
  end
  fab!(:staged_user) { Fabricate(:user, staged: true) }
  fab!(:suspended_user) { Fabricate(:user, suspended_till: 1.day.from_now) }
  fab!(:silenced_user) { Fabricate(:user, silenced_till: 2.day.from_now) }
  fab!(:inactive_user) { Fabricate(:user, active: false) }
  fab!(:anonymous_user) do
    # When using the `anonymous` fabricator, the `::Chat::AutoJoinChannels` is called in the
    # `on(:user_added_to_group)` hook **before** the `anonymous_user` record is created in the `after_create` hook
    anon = Fabricate(:user)
    AnonymousUser.create!(user: anon, master_user: anon, active: true)
    anon
  end

  before { Jobs.run_immediately! }

  it "does not auto join users without permissions" do
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
    _bot = Fabricate(:user, id: [User.minimum(:id), 0].min - 1)

    job.execute({})

    # excludes bot / chat disabled / inactive / staged / suspended / silenced / anonymous users
    expect(
      Chat::UserChatChannelMembership.where(chat_channel: channel).pluck(:user_id),
    ).to contain_exactly(user.id)

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
