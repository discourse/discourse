# frozen_string_literal: true

RSpec.describe "User Notes", type: :system do
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
end
