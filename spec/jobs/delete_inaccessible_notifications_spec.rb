# frozen_string_literal: true

RSpec.describe Jobs::DeleteInaccessibleNotifications do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:pm) { Fabricate(:private_message_topic, user: admin, recipient: user) }

  it "raises if topic_id is missing" do
    expect { described_class.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "does nothing when the topic is gone" do
    expect { described_class.new.execute(topic_id: -1) }.not_to raise_error
  end

  it "deletes notifications for users who can no longer see the topic" do
    other_notification = Fabricate(:notification, user: other_user, topic: pm, read: false) # not an allowed user

    expect { described_class.new.execute(topic_id: pm.id) }.to change {
      Notification.exists?(other_notification.id)
    }.from(true).to(false)
  end

  it "preserves notifications for users who can still see the topic" do
    notification = Fabricate(:notification, user: user, topic: pm, read: false)

    expect { described_class.new.execute(topic_id: pm.id) }.not_to change {
      Notification.exists?(notification.id)
    }
  end

  it "publishes notification state once per affected user, not per notification" do
    Fabricate(:notification, user: other_user, topic: pm)
    Fabricate(:notification, user: other_user, topic: pm)
    Fabricate(:notification, user: other_user, topic: pm)

    User.any_instance.expects(:publish_notifications_state).once

    described_class.new.execute(topic_id: pm.id)
  end

  context "with user_ids arg" do
    it "only considers the given users" do
      Fabricate(:notification, user: other_user, topic: pm)
      third_user = Fabricate(:user)
      third_notification = Fabricate(:notification, user: third_user, topic: pm)

      described_class.new.execute(topic_id: pm.id, user_ids: [other_user.id])

      expect(Notification.exists?(third_notification.id)).to eq(true)
    end
  end

  it "resolves PM access without an SQL query per user" do
    group = Fabricate(:group)
    group_pm =
      Fabricate(
        :private_message_topic,
        user: admin,
        topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
      )
    users = 5.times.map { Fabricate(:user) }
    users.each { |u| Fabricate(:notification, user: u, topic: group_pm) }

    access_queries = 0
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        # Guardian's per-PM access check hits topic_allowed_users/topic_allowed_groups.
        access_queries += 1 if event.payload[:sql] =~ /topic_allowed_(users|groups)/
      end

    begin
      described_class.new.execute(topic_id: group_pm.id)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    expect(access_queries).to be <= 2
  end
end
