# frozen_string_literal: true

RSpec.describe Jobs::NotifyStaffReviewableNote do
  fab!(:reviewable, :reviewable_flagged_post)
  fab!(:author, :admin)
  fab!(:recipient, :moderator)
  fab!(:other_staff, :admin)
  fab!(:regular_user, :user)
  fab!(:group)

  let(:notifications) do
    Notification.where(notification_type: Notification.types[:staff_reviewable_note])
  end

  before do
    Jobs.run_immediately!
    [author, recipient, regular_user].each { |user| group.add(user) }
  end

  it "does not notify staff by default" do
    ReviewableNote.create!(reviewable:, user: author, content: "Needs a second opinion")

    expect(notifications).to be_empty
  end

  it "notifies configured staff once and excludes the author and nonstaff" do
    SiteSetting.reviewable_note_notification_groups = group.id.to_s
    note = ReviewableNote.create!(reviewable:, user: author, content: "Needs a second opinion")
    described_class.new.execute(note_id: note.id)

    expect(notifications.pluck(:user_id)).to eq([recipient.id])
    expect(notifications.first.data_hash).to eq(
      "reviewable_id" => reviewable.id,
      "reviewable_note_id" => note.id,
    )
  end

  it "supports the logged-in users group without notifying nonstaff" do
    SiteSetting.reviewable_note_notification_groups = Group::AUTO_GROUPS[:logged_in_users].to_s

    ReviewableNote.create!(reviewable:, user: author, content: "Needs a second opinion")

    expect(notifications.pluck(:user_id)).to contain_exactly(recipient.id, other_staff.id)
  end

  it "only notifies staff who can see the review item" do
    SiteSetting.reviewable_note_notification_groups = group.id.to_s
    group.add(other_staff)
    reviewable.update!(reviewable_by_moderator: false)

    ReviewableNote.create!(reviewable:, user: author, content: "Needs a second opinion")

    expect(notifications.pluck(:user_id)).to eq([other_staff.id])
  end

  it "does not send a second notification to a mentioned recipient" do
    SiteSetting.enable_mentions = true
    SiteSetting.reviewable_note_notification_groups = group.id.to_s

    ReviewableNote.create!(reviewable:, user: author, content: "@#{recipient.username} take a look")

    expect(recipient.notifications.pluck(:notification_type)).to eq(
      [Notification.types[:mentioned]],
    )
  end
end
