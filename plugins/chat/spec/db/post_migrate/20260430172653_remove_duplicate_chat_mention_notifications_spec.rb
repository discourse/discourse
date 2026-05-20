# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/post_migrate/20260430172653_remove_duplicate_chat_mention_notifications.rb",
        )

describe RemoveDuplicateChatMentionNotifications do
  fab!(:user_1, :user)
  fab!(:user_2, :user)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def insert_notification(
    user:,
    type: 29,
    data: '{"chat_message_id":1}',
    read: false,
    created_at: "2026-04-29 12:00:00"
  )
    DB.query_single(
      <<~SQL,
      INSERT INTO notifications (notification_type, user_id, data, read, high_priority, created_at, updated_at)
      VALUES (:type, :user_id, :data, :read, false, :created_at, :created_at)
      RETURNING id
    SQL
      user_id: user.id,
      type: type,
      data: data,
      read: read,
      created_at: created_at,
    ).first
  end

  def insert_mention_join(notification_id, chat_mention_id: 1)
    DB.exec(<<~SQL, notification_id: notification_id, chat_mention_id: chat_mention_id)
      INSERT INTO chat_mention_notifications (notification_id, chat_mention_id)
      VALUES (:notification_id, :chat_mention_id)
    SQL
  end

  def notification_ids_for(user)
    DB.query_single("SELECT id FROM notifications WHERE user_id = :id ORDER BY id", id: user.id)
  end

  def join_ids_for(notification_ids)
    DB.query_single(
      "SELECT notification_id FROM chat_mention_notifications WHERE notification_id IN (:ids) ORDER BY notification_id",
      ids: notification_ids,
    )
  end

  it "collapses duplicate chat_mention rows for the same user/data, keeping the oldest" do
    kept = insert_notification(user: user_1)
    dup_a = insert_notification(user: user_1)
    dup_b = insert_notification(user: user_1)

    described_class.new.up

    expect(notification_ids_for(user_1)).to eq([kept])
  end

  it "preserves distinct chat_mention rows (different data) for the same user" do
    a = insert_notification(user: user_1, data: '{"chat_message_id":1}')
    b = insert_notification(user: user_1, data: '{"chat_message_id":2}')

    described_class.new.up

    expect(notification_ids_for(user_1)).to contain_exactly(a, b)
  end

  it "marks the kept row read when any duplicate sibling was read" do
    kept = insert_notification(user: user_1, read: false)
    insert_notification(user: user_1, read: true)

    described_class.new.up

    read_state = DB.query_single("SELECT read FROM notifications WHERE id = :id", id: kept).first
    expect(read_state).to eq(true)
  end

  it "leaves the kept row read state unchanged when no sibling was read" do
    kept = insert_notification(user: user_1, read: false)
    insert_notification(user: user_1, read: false)

    described_class.new.up

    read_state = DB.query_single("SELECT read FROM notifications WHERE id = :id", id: kept).first
    expect(read_state).to eq(false)
  end

  it "deletes orphaned chat_mention_notifications join rows for removed duplicates" do
    kept = insert_notification(user: user_1)
    dup = insert_notification(user: user_1)
    insert_mention_join(kept, chat_mention_id: 100)
    insert_mention_join(dup, chat_mention_id: 100)

    described_class.new.up

    expect(join_ids_for([kept, dup])).to eq([kept])
  end

  it "ignores rows created before the deploy window" do
    a = insert_notification(user: user_1, created_at: "2026-04-28 23:59:00")
    b = insert_notification(user: user_1, created_at: "2026-04-28 23:59:30")

    described_class.new.up

    expect(notification_ids_for(user_1)).to contain_exactly(a, b)
  end

  it "ignores other notification types that share user/data shape" do
    chat_kept = insert_notification(user: user_1, type: 29)
    insert_notification(user: user_1, type: 29) # dup, should be removed
    other = insert_notification(user: user_1, type: 1) # mentioned, untouched
    other_dup = insert_notification(user: user_1, type: 1) # also untouched

    described_class.new.up

    expect(notification_ids_for(user_1)).to contain_exactly(chat_kept, other, other_dup)
  end

  it "dedupes independently for each affected user" do
    kept_1 = insert_notification(user: user_1)
    insert_notification(user: user_1)
    kept_2 = insert_notification(user: user_2)
    insert_notification(user: user_2)

    described_class.new.up

    expect(notification_ids_for(user_1)).to eq([kept_1])
    expect(notification_ids_for(user_2)).to eq([kept_2])
  end
end
