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
end
