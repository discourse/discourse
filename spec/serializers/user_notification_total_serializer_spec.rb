# frozen_string_literal: true

RSpec.describe UserNotificationTotalSerializer do
  fab!(:user) { Fabricate(:user, trust_level: 3) }

  fab!(:notification) { Fabricate(:notification, user: user, read: false) }
  fab!(:pm_sender, :user)
  fab!(:pm_topic) { Fabricate(:private_message_topic, user: pm_sender, recipient: user) }
  fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: pm_sender) }
  fab!(:pm_notification) do
    Fabricate(:private_message_notification, user: user, topic: pm_topic, post: pm_post)
  end
  fab!(:pm_notification2) do
    Fabricate(:private_message_notification, user: user, topic: pm_topic, post: pm_post)
  end
  fab!(:group_message_notification) do
    Fabricate(
      :notification,
      user: user,
      notification_type: Notification.types[:group_message_summary],
      data: { group_id: 1, group_name: "Group", inbox_count: 5 }.to_json,
    )
  end
  fab!(:reviewable)

  let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }
  let(:serialized_data) { serializer.as_json }

  it "includes the user's unread regular notifications count" do
    # notification + group_message_notification - pm_notifications
    expect(serialized_data[:unread_notifications]).to eq(2)
  end

  it "includes the user's unread private messages count" do
    expect(serialized_data[:unread_personal_messages]).to eq(2)
  end

  it "excludes non-normal PM subtypes from notification totals" do
    sender = Fabricate(:user)
    custom_pm_topic =
      Fabricate(
        :private_message_topic,
        user: sender,
        recipient: user,
        subtype: "custom_personal_message",
      )
    custom_pm_post = Fabricate(:post, topic: custom_pm_topic, user: sender)

    Fabricate(
      :private_message_notification,
      user: user,
      topic: custom_pm_topic,
      post: custom_pm_post,
      read: false,
    )

    expect(serialized_data).to include(unread_notifications: 2, unread_personal_messages: 2)
  end

  context "when the user has PMs disabled" do
    it "does not include the user's unread private messages count" do
      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(serialized_data).not_to have_key(:unread_personal_messages)
    end
  end

  it "includes group inbox notification counts" do
    expect(serialized_data[:group_inboxes]).to contain_exactly(
      { group_id: 1, group_name: "Group", count: 5 },
    )
  end

  context "when the user is staff" do
    before { user.update!(admin: true) }

    it "includes the count of unseen reviewables" do
      expect(serialized_data[:unseen_reviewables]).to eq(1)
    end
  end

  context "when the user is not staff" do
    it "does not include unseen reviewables counts" do
      expect(serialized_data).not_to have_key(:unseen_reviewables)
    end
  end
end
