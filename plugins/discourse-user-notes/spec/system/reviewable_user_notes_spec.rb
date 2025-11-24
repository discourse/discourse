# frozen_string_literal: true

RSpec.describe "Reviewable User Notes", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:reviewable_flagged_post)

  let(:review_page) { PageObjects::Pages::RefreshedReview.new }
  let(:review_note_form) { PageObjects::Components::ReviewNoteForm.new }
  let(:user_notes_modal) { PageObjects::Modals::Base.new }

  before do
    SiteSetting.user_notes_enabled = true
    SiteSetting.reviewable_ui_refresh = "staff"
    sign_in(admin)
  end

  it "copies reviewable note to user notes with reviewable_id when checkbox is checked" do
    review_page.visit_reviewable(reviewable_flagged_post)
    review_page.click_timeline_tab

    review_note_form.form.fill_in("content", with: "This user needs attention")
    review_note_form.form.field("copy_note_to_user").toggle
    review_note_form.form.submit

    expect(page).to have_text("This user needs attention")

    visit(
      "/admin/users/#{reviewable_flagged_post.target_created_by.id}/#{reviewable_flagged_post.target_created_by.username}",
    )

    click_button(class: "show-user-notes-btn")

    expect(user_notes_modal).to be_open
    expect(user_notes_modal).to have_content("This user needs attention")

    expect(user_notes_modal).to have_link(
      I18n.t("js.user_notes.show_reviewable"),
      href: "/review/#{reviewable_flagged_post.id}",
    )
  end

  it "does not display reviewable link for regular user notes without reviewable_id" do
    visit("/admin/users/#{user.id}/#{user.username}")

    click_button(class: "show-user-notes-btn")
    expect(user_notes_modal).to be_open

    form = PageObjects::Components::FormKit.new(".user-notes-modal .form-kit")
    form.field("content").fill_in("Regular note without reviewable")
    form.submit

    expect(user_notes_modal).to be_open
    expect(user_notes_modal).to have_content("Regular note without reviewable")

    expect(user_notes_modal).not_to have_link(
      I18n.t("js.user_notes.show_reviewable"),
      href: "/review/#{reviewable_flagged_post.id}",
    )
  end
end
