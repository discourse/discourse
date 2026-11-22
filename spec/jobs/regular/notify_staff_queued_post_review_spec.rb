# frozen_string_literal: true

RSpec.describe Jobs::NotifyStaffQueuedPostReview do
  fab!(:reviewable, :reviewable_queued_post)
  fab!(:acting_staff, :admin)
  fab!(:recipient, :moderator)
  fab!(:other_staff, :admin)
  fab!(:nonstaff, :user)
  fab!(:recipient_group, :group)

  let(:notifications) do
    Notification.where(notification_type: Notification.types[:staff_queued_post_review])
  end

  before do
    Jobs.run_immediately!
    [acting_staff, recipient, nonstaff].each { |user| recipient_group.add(user) }
  end

  it "does not notify staff by default" do
    expect(reviewable.perform(acting_staff, :approve_post)).to be_success
    expect(notifications).to be_empty
  end

  it "notifies staff on approval once and excludes the actor and other users" do
    SiteSetting.staff_queued_post_approval_notification_groups = recipient_group.id.to_s

    expect(reviewable.perform(acting_staff, :approve_post)).to be_success
    history = reviewable.reviewable_histories.find_by!(type: :transitioned)
    described_class.new.execute(history_id: history.id)

    expect(notifications.pluck(:user_id)).to eq([recipient.id])
    expect(notifications.first.data_hash).to eq(
      "reviewable_id" => reviewable.id,
      "reviewable_history_id" => history.id,
      "outcome" => "approved",
    )
  end

  it "does not send a rejection to groups configured only for approvals" do
    SiteSetting.staff_queued_post_approval_notification_groups = recipient_group.id.to_s
    expect(reviewable.perform(acting_staff, :reject_post)).to be_success
    expect(notifications).to be_empty
  end

  it "checks review permissions when notifying staff on rejection" do
    hidden_category = Fabricate(:private_category, group: Fabricate(:group))
    reviewable.update!(category: hidden_category)
    recipient_group.add(other_staff)
    SiteSetting.staff_queued_post_rejection_notification_groups = recipient_group.id.to_s

    expect(reviewable.perform(acting_staff, :reject_post)).to be_success

    expect(notifications.pluck(:user_id)).to eq([other_staff.id])
    expect(notifications.first.data_hash["outcome"]).to eq("rejected")
  end
end
