# frozen_string_literal: true

return if !defined?(Chat)

describe DiscoursePostEvent::ChatChannelSync do
  fab!(:user)
  fab!(:admin)
  fab!(:admin_post) { Fabricate(:post, user: admin) }

  it "is able to create a chat channel and sync members" do
    event = Fabricate(:event, chat_enabled: true, post: admin_post, name: "Test Event")

    expect(event.chat_channel_id).to be_present
    expect(event.chat_channel.name).to eq(event.name)
    expect(event.chat_channel.user_chat_channel_memberships.count).to eq(1)
    expect(event.chat_channel.user_chat_channel_memberships.first.user_id).to eq(admin.id)

    event.create_invitees([user_id: user.id, status: DiscoursePostEvent::Invitee.statuses[:going]])
    event.save!

    expect(event.chat_channel.user_chat_channel_memberships.count).to eq(2)
  end

  it "will simply do nothing if user has no permission to create channel" do
    post = Fabricate(:post, user: user)
    event = Fabricate(:event, chat_enabled: true, post: post)

    expect(event.chat_channel_id).to be_nil
  end

  it "defaults event name to post title" do
    event = Fabricate(:event, chat_enabled: true, post: admin_post)

    expect(event.chat_channel.name).to eq(admin_post.topic.title)
  end

  describe "user filtering" do
    fab!(:suspended_user) { Fabricate(:user, suspended_till: 1.year.from_now) }
    fab!(:silenced_user) { Fabricate(:user, silenced_till: 1.year.from_now) }
    fab!(:staged_user) { Fabricate(:user, staged: true) }
    fab!(:regular_user, :user)

    it "does not add suspended users to the chat channel" do
      event = Fabricate(:event, chat_enabled: true, post: admin_post, name: "Test Event")
      event.create_invitees(
        [user_id: suspended_user.id, status: DiscoursePostEvent::Invitee.statuses[:going]],
      )
      event.save!

      expect(event.chat_channel.user_chat_channel_memberships.pluck(:user_id)).not_to include(
        suspended_user.id,
      )
    end

    it "does not add silenced users to the chat channel" do
      event = Fabricate(:event, chat_enabled: true, post: admin_post, name: "Test Event")
      event.create_invitees(
        [user_id: silenced_user.id, status: DiscoursePostEvent::Invitee.statuses[:going]],
      )
      event.save!

      expect(event.chat_channel.user_chat_channel_memberships.pluck(:user_id)).not_to include(
        silenced_user.id,
      )
    end

    it "does not add staged users to the chat channel" do
      event = Fabricate(:event, chat_enabled: true, post: admin_post, name: "Test Event")
      event.create_invitees(
        [user_id: staged_user.id, status: DiscoursePostEvent::Invitee.statuses[:going]],
      )
      event.save!

      expect(event.chat_channel.user_chat_channel_memberships.pluck(:user_id)).not_to include(
        staged_user.id,
      )
    end

    it "adds regular users to the chat channel" do
      event = Fabricate(:event, chat_enabled: true, post: admin_post, name: "Test Event")
      event.create_invitees(
        [user_id: regular_user.id, status: DiscoursePostEvent::Invitee.statuses[:going]],
      )
      event.save!

      expect(event.chat_channel.user_chat_channel_memberships.pluck(:user_id)).to include(
        regular_user.id,
      )
    end

    it "adds users whose suspension has expired to the chat channel" do
      formerly_suspended = Fabricate(:user, suspended_till: 1.day.ago)
      event = Fabricate(:event, chat_enabled: true, post: admin_post, name: "Test Event")
      event.create_invitees(
        [user_id: formerly_suspended.id, status: DiscoursePostEvent::Invitee.statuses[:going]],
      )
      event.save!

      expect(event.chat_channel.user_chat_channel_memberships.pluck(:user_id)).to include(
        formerly_suspended.id,
      )
    end
  end
end
