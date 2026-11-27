# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20261127130841_backfill_notification_user_ids.rb")

RSpec.describe BackfillNotificationUserIds do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "backfills user IDs, preserves non-user display labels, and strips usernames and names" do
    alice = Fabricate(:user, username: "Alice_Cap", name: "Alice Secret")
    bob = Fabricate(:user, username: "bob", name: "Bob Secret")
    recipient = Fabricate(:user)
    support_group = Fabricate(:group)

    paired_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:liked],
        data: {
          original_username: "Alice_Cap",
          original_name: "Alice Secret",
          display_username: "alice_cap",
          display_name: "Alice Secret",
          username: "alice_cap",
          name: "Alice Secret",
          username2: "bob",
          name2: "Bob Secret",
        }.to_json,
      ).first

    collapsed_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:replied],
        data: {
          original_username: "bob",
          display_username: "2 replies",
          display_name: "Alice Secret",
        }.to_json,
      ).first

    editor = Fabricate(:user)
    edited_post = Fabricate(:post, user: alice, last_editor_id: editor.id)

    deleted_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:chat_mention],
        data: {
          display_username: "deleted_user",
          mentioned_by_username: "deleted_user",
          invited_by_username: "bob",
        }.to_json,
      ).first

    group_assign_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:assigned],
        data: {
          message: "discourse_assign.assign_group_notification",
          display_username: support_group.name,
        }.to_json,
      ).first

    edited_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:edited],
        data: {
          original_post_id: edited_post.id,
          original_username: "stale_author",
          display_username: "stale_editor",
        }.to_json,
      ).first

    cjk_collapsed_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:replied],
        data: { original_username: "bob", display_username: "2件の返信" }.to_json,
      ).first

    negative_actor_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:custom],
        data: { acting_user_id: Discourse::SYSTEM_USER_ID, name: "System" }.to_json,
      ).first

    array_data_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:custom],
        data: "[]",
      ).first

    long_data_id =
      DB.query_single(
        <<~SQL,
          INSERT INTO notifications (user_id, notification_type, data, created_at, updated_at)
          VALUES (:user_id, :notification_type, :data, NOW(), NOW())
          RETURNING id
        SQL
        user_id: recipient.id,
        notification_type: Notification.types[:liked],
        data: { topic_title: "x" * 930, username: "bob", display_username: "bob" }.to_json,
      ).first

    described_class.new.up

    paired = JSON.parse(Notification.find(paired_id).data)
    expect(paired).to eq(
      "original_user_id" => alice.id,
      "display_user_id" => alice.id,
      "acting_user_id" => alice.id,
      "user2_id" => bob.id,
    )

    collapsed = JSON.parse(Notification.find(collapsed_id).data)
    expect(collapsed).to eq("original_user_id" => bob.id, "display_label" => "2 replies")

    deleted = JSON.parse(Notification.find(deleted_id).data)
    expect(deleted).to eq("invited_by_user_id" => bob.id)

    group_assign = JSON.parse(Notification.find(group_assign_id).data)
    expect(group_assign).to eq(
      "message" => "discourse_assign.assign_group_notification",
      "display_label" => support_group.name,
    )

    edited = JSON.parse(Notification.find(edited_id).data)
    expect(edited).to eq(
      "original_post_id" => edited_post.id,
      "original_user_id" => alice.id,
      "display_user_id" => editor.id,
    )

    cjk_collapsed = JSON.parse(Notification.find(cjk_collapsed_id).data)
    expect(cjk_collapsed).to eq("original_user_id" => bob.id, "display_label" => "2件の返信")

    negative_actor = JSON.parse(Notification.find(negative_actor_id).data)
    expect(negative_actor).to eq("acting_user_id" => Discourse::SYSTEM_USER_ID)

    expect(Notification.find(array_data_id).data).to eq("[]")

    long_raw = Notification.find(long_data_id).data
    expect(long_raw.length).to be <= 1000
    long_parsed = JSON.parse(long_raw)
    expect(long_parsed["acting_user_id"]).to eq(bob.id)
    expect(long_parsed["display_user_id"]).to eq(bob.id)
  end
end
