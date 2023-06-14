# frozen_string_literal: true

require Rails.root.join("plugins/chat/db/migrate/20230607091233_backfill_thread_memberships.rb")

RSpec.describe BackfillThreadMemberships do
  fab!(:thread_1) { Fabricate(:chat_thread) }
  fab!(:thread_2) { Fabricate(:chat_thread) }
  fab!(:user_1) { Fabricate(:user) }

  it "does not add memberships for users that already are a member of a thread" do
    thread_1.add(user_1)
    expect { subject.up }.not_to change {
      ::Chat::UserChatThreadMembership.where(user: user_1, thread: thread_1).count
    }
  end

  it "does not add memberships for users that already are a member of a thread and have the notification_level set to something other than tracking" do
    thread_1.add(user_1)
    thread_1.membership_for(user_1).update!(
      notification_level: ::Chat::UserChatThreadMembership.notification_levels[:muted],
    )
    expect { subject.up }.not_to change {
      ::Chat::UserChatThreadMembership.where(user: user_1, thread: thread_1).count
    }
  end

  it "creates a membership for users who have sent a message in a thread but do not have a membership record" do
    Fabricate(:chat_message, user: user_1, thread: thread_1, chat_channel: thread_1.channel)
    thread_1.remove(user_1)
    expect { subject.up }.to change {
      ::Chat::UserChatThreadMembership.where(user: user_1, thread: thread_1).count
    }.by(1)
  end

  it "sets the last_read_message_id to the latest message in the thread for users who have a membership created" do
    Fabricate(:chat_message, user: user_1, thread: thread_1, chat_channel: thread_1.channel)
    thread_1.remove(user_1)
    latest_message = Fabricate(:chat_message, thread: thread_1, chat_channel: thread_1.channel)
    subject.up
    expect(
      ::Chat::UserChatThreadMembership.find_by(user: user_1, thread: thread_1).last_read_message_id,
    ).to eq(latest_message.id)
  end

  it "sets the last_read_message_id to the original message if all thread replies have been trashed" do
    msg = Fabricate(:chat_message, user: user_1, thread: thread_1, chat_channel: thread_1.channel)
    thread_1.remove(user_1)
    msg.trash!
    subject.up
    expect(
      ::Chat::UserChatThreadMembership.find_by(user: user_1, thread: thread_1).last_read_message_id,
    ).to eq(thread_1.original_message.id)
  end

  it "does create a membership for users who sent a now-deleted message in a thread" do
    trashed_message =
      Fabricate(:chat_message, user: user_1, thread: thread_1, chat_channel: thread_1.channel)
    thread_1.remove(user_1)
    trashed_message.trash!
    expect { subject.up }.to change {
      ::Chat::UserChatThreadMembership.where(user: user_1, thread: thread_1).count
    }.by(1)
  end
end
