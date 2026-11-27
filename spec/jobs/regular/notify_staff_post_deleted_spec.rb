# frozen_string_literal: true

RSpec.describe Jobs::NotifyStaffPostDeleted do
  fab!(:admin)
  fab!(:recipient, :moderator)
  fab!(:other_staff, :moderator)
  fab!(:regular_user, :user)
  fab!(:notification_group, :group)
  fab!(:first_post, :post)
  fab!(:reply) { Fabricate(:post, topic: first_post.topic) }

  let(:notification_type) { Notification.types[:staff_post_deleted] }
  let(:notifications) { Notification.where(notification_type: notification_type) }

  before do
    Jobs.run_immediately!
    notification_group.add(admin)
    notification_group.add(recipient)
    notification_group.add(regular_user)
  end

  it "does not send a notification by default" do
    PostDestroyer.new(admin, reply).destroy

    expect(notifications).to be_empty
  end

  it "notifies eligible staff once even if the job is retried" do
    SiteSetting.staff_post_deletion_notification_groups = notification_group.id.to_s

    PostDestroyer.new(admin, reply).destroy
    history = UserHistory.find_by!(post_id: reply.id, action: UserHistory.actions[:delete_post])
    described_class.new.execute(history_id: history.id)

    notification = notifications.sole
    expect(notification).to have_attributes(user_id: recipient.id, topic_id: reply.topic_id)
    expect(notification.data_hash).to eq("staff_action_id" => history.id)
  end

  it "does not notify staff who cannot see the topic" do
    SiteSetting.staff_post_deletion_notification_groups = notification_group.id.to_s
    category = Fabricate(:private_category, group: Fabricate(:group))
    reply.topic.update!(category:)
    expect(recipient.guardian.can_see_topic?(reply.topic)).to eq(false)

    PostDestroyer.new(admin, reply).destroy

    expect(notifications).to be_empty
  end
end
