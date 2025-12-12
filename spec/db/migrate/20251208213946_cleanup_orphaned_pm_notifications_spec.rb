# frozen_string_literal: true

require Rails.root.join("db/migrate/20251208213946_cleanup_orphaned_pm_notifications.rb")

RSpec.describe CleanupOrphanedPmNotifications do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  fab!(:user1, :user)
  fab!(:user2, :user)
  fab!(:admin)
  fab!(:group)

  fab!(:pm_topic) do
    Fabricate(
      :private_message_topic,
      user: admin,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: admin),
        Fabricate.build(:topic_allowed_user, user: user1),
      ],
    )
  end

  fab!(:group_pm_topic) do
    topic =
      Fabricate(
        :private_message_topic,
        user: admin,
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
      )
    Fabricate(:topic_allowed_group, topic: topic, group: group)
    topic
  end

  it "deletes notifications for users removed from PM" do
    # user2 is not in pm_topic but has orphaned notifications
    orphaned_notification =
      Fabricate(
        :notification,
        user: user2,
        topic: pm_topic,
        notification_type: Notification.types[:private_message],
      )

    CleanupOrphanedPmNotifications.new.up

    expect(Notification.exists?(orphaned_notification.id)).to eq(false)
  end

  it "preserves notifications for users still in PM" do
    # user1 is in pm_topic
    valid_notification =
      Fabricate(
        :notification,
        user: user1,
        topic: pm_topic,
        notification_type: Notification.types[:private_message],
      )

    CleanupOrphanedPmNotifications.new.up

    expect(Notification.exists?(valid_notification.id)).to eq(true)
  end

  it "preserves notifications for users with access via group" do
    group.add(user2)

    # user2 has access to group_pm_topic via group membership
    valid_notification =
      Fabricate(
        :notification,
        user: user2,
        topic: group_pm_topic,
        notification_type: Notification.types[:private_message],
      )

    CleanupOrphanedPmNotifications.new.up

    expect(Notification.exists?(valid_notification.id)).to eq(true)
  end

  it "deletes all notification types for removed users" do
    # Any notification type from a PM should be deleted if user was removed
    notification_types = %i[private_message invited_to_private_message mentioned quoted replied]

    notifications =
      notification_types.map do |type|
        Fabricate(
          :notification,
          user: user2,
          topic: pm_topic,
          notification_type: Notification.types[type],
        )
      end

    CleanupOrphanedPmNotifications.new.up

    notifications.each { |notification| expect(Notification.exists?(notification.id)).to eq(false) }
  end
end
