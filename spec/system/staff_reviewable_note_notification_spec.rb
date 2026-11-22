# frozen_string_literal: true

describe "Staff review note notification" do
  fab!(:reviewable, :reviewable_flagged_post)
  fab!(:author, :admin)
  fab!(:recipient, :moderator)
  fab!(:group)

  it "links staff to a review item only while they can access it" do
    Jobs.run_immediately!
    group.add(recipient)
    SiteSetting.reviewable_note_notification_groups = group.id.to_s
    ReviewableNote.create!(reviewable:, user: author, content: "Needs a second opinion")
    sign_in(recipient)

    visit "/u/#{recipient.username}/notifications"

    expect(page).to have_link(
      I18n.t("js.notifications.staff_reviewable_note"),
      href: "/review/#{reviewable.id}",
    )

    reviewable.update!(reviewable_by_moderator: false)
    visit "/u/#{recipient.username}/notifications"

    expect(page).to have_no_link(href: "/review/#{reviewable.id}")
  end
end
