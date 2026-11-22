# frozen_string_literal: true

RSpec.describe "User Notes" do
  fab!(:admin)
  fab!(:user)

  before { SiteSetting.user_notes_enabled = true }

  it "allows admin to manage user notes" do
    sign_in(admin)

    visit("/admin/users/#{user.id}/#{user.username}")

    expect(page).to have_css(".show-user-notes-btn")
    click_button(class: "show-user-notes-btn")

    expect(page).to have_css(".user-notes-modal")

    form = PageObjects::Components::FormKit.new(".user-notes-modal .form-kit")
    form.field("content").fill_in("A NOTE")
    form.submit

    expect(page).to have_css(".user-note", text: "A NOTE")

    find(".user-note .btn-danger").click

    PageObjects::Components::Dialog.new.click_danger

    expect(page).to have_no_css(".user-note", text: "A NOTE")
  end

  it "links a new note notification to the user's profile" do
    Jobs.run_immediately!
    moderator = Fabricate(:moderator)
    group = Fabricate(:group)
    group.add(moderator)
    SiteSetting.user_notes_notification_groups = group.id.to_s
    DiscourseUserNotes.add_note(user, "Staff-only text", admin.id)
    sign_in(moderator)

    visit "/u/#{moderator.username}/notifications"

    expect(page).to have_link(href: "/u/#{user.username}", text: "A user note was added")
  end
end
