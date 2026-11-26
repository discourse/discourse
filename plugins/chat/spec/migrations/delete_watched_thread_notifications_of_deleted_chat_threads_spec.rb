# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/post_migrate/20261126090000_delete_watched_thread_notifications_of_deleted_chat_threads.rb",
        )

RSpec.describe DeleteWatchedThreadNotificationsOfDeletedChatThreads do
  fab!(:watcher, :user)

  def migrate
    migration = described_class.new
    migration.suppress_messages { migration.up }
  end

  def watched_thread_notification(thread)
    thread.add(watcher, notification_level: :watching)

    Fabricate(
      :notification,
      user: watcher,
      topic: nil,
      notification_type: Notification.types[:chat_watched_thread],
      data: { chat_thread_id: thread.id, description: thread.original_message.message }.to_json,
    )
  end

  it "deletes the notifications of threads that are destroyed or whose original message is trashed or destroyed" do
    kept = watched_thread_notification(Fabricate(:chat_thread))
    trashed_thread = Fabricate(:chat_thread)
    for_trashed = watched_thread_notification(trashed_thread)
    trashed_thread.original_message.trash!
    destroyed_thread = Fabricate(:chat_thread)
    for_destroyed = watched_thread_notification(destroyed_thread)
    destroyed_thread.original_message.destroy!
    removed_thread = Fabricate(:chat_thread)
    for_removed = watched_thread_notification(removed_thread)
    removed_thread.destroy!

    migrate

    expect(
      Notification.where(id: [kept.id, for_trashed.id, for_destroyed.id, for_removed.id]),
    ).to contain_exactly(kept)
  end
end
