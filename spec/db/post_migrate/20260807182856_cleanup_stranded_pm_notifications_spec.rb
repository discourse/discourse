# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260807182856_cleanup_stranded_pm_notifications.rb")

RSpec.describe CleanupStrandedPmNotifications do
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

  it "deletes notifications for users removed from a PM" do
    orphaned = Fabricate(:notification, user: user2, topic: pm_topic)

    described_class.new.up

    expect(Notification.exists?(orphaned.id)).to eq(false)
  end

  it "preserves notifications for users still allowed on the PM" do
    kept = Fabricate(:notification, user: user1, topic: pm_topic)

    described_class.new.up

    expect(Notification.exists?(kept.id)).to eq(true)
  end

  it "preserves notifications for users with access via a group" do
    group.add(user2)
    kept = Fabricate(:notification, user: user2, topic: group_pm_topic)

    described_class.new.up

    expect(Notification.exists?(kept.id)).to eq(true)
  end

  it "deletes all notification types from an inaccessible PM" do
    types = %i[private_message invited_to_private_message mentioned quoted replied]
    orphaned =
      types.map do |type|
        Fabricate(
          :notification,
          user: user2,
          topic: pm_topic,
          notification_type: Notification.types[type],
        )
      end

    described_class.new.up

    orphaned.each { |n| expect(Notification.exists?(n.id)).to eq(false) }
  end

  it "leaves non-PM notifications alone" do
    regular_topic = Fabricate(:topic)
    kept = Fabricate(:notification, user: user2, topic: regular_topic)

    described_class.new.up

    expect(Notification.exists?(kept.id)).to eq(true)
  end
end
