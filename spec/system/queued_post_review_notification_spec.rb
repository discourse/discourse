# frozen_string_literal: true

describe "Queued post review notification" do
  fab!(:reviewable, :reviewable_queued_post)
  fab!(:actor, :admin)
  fab!(:recipient, :moderator)
  fab!(:recipient_group, :group)

  it "links the configured staff recipient to the rejected item" do
    Jobs.run_immediately!
    recipient_group.add(recipient)
    SiteSetting.staff_queued_post_rejection_notification_groups = recipient_group.id.to_s
    expect(reviewable.perform(actor, :reject_post)).to be_success
    sign_in(recipient)

    visit "/u/#{recipient.username}/notifications"

    expect(page).to have_link(
      I18n.t("js.notifications.staff_queued_post_rejected"),
      href: "/review/#{reviewable.id}",
    )

    reviewable.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
    visit "/u/#{recipient.username}/notifications"

    expect(page).to have_no_link(href: "/review/#{reviewable.id}")
  end
end
