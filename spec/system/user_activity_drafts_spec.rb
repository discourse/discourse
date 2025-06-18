# frozen_string_literal: true

describe "User activity drafts", type: :system do
  let(:user) { Fabricate(:user) }
  let(:user_activity_drafts) { PageObjects::Pages::UserActivityDrafts.new }

  before do
    # Clear all drafts to start fresh
    Draft.delete_all
    sign_in(user)
  end

  it "shows clear all drafts button only when multiple drafts exist" do
    # Start with no drafts - button should not be visible
    visit "/u/#{user.username_lower}/activity/drafts"
    expect(user_activity_drafts).to have_no_clear_all_drafts_button

    # Create one draft
    topic = Fabricate(:topic)
    Draft.set(user, "topic_#{topic.id}", 0, { reply: "First draft content" }.to_json)

    # Reload page and verify button is not visible with one draft
    visit "/u/#{user.username_lower}/activity/drafts"
    expect(user_activity_drafts).to have_drafts
    expect(user_activity_drafts).to have_no_clear_all_drafts_button

    # Create a second draft with a different key
    Draft.set(user, Draft::NEW_PRIVATE_MESSAGE, 0, { reply: "Second draft" }.to_json)

    # Reload page and verify button is now visible with multiple drafts
    visit "/u/#{user.username_lower}/activity/drafts"
    expect(user_activity_drafts).to have_clear_all_drafts_button

    # Remove one draft
    user_activity_drafts.remove_first_draft
    find(".dialog-footer .btn-danger").click
    page.refresh

    # Button should be hidden again with only one draft left
    expect(user_activity_drafts).to have_no_clear_all_drafts_button
  end

  it "can clear all drafts" do
    # Create multiple drafts
    topic1 = Fabricate(:topic)
    topic2 = Fabricate(:topic)
    Draft.set(user, "topic_#{topic1.id}", 0, { reply: "Draft 1" }.to_json)
    Draft.set(user, "topic_#{topic2.id}", 0, { reply: "Draft 2" }.to_json)

    # Visit page and verify drafts exist
    visit "/u/#{user.username_lower}/activity/drafts"
    expect(page).to have_css(".user-stream-item", count: 2)

    # Click the clear all button and confirm
    user_activity_drafts.click_clear_all_drafts
    find(".dialog-footer .btn-danger").click

    # All drafts should be removed
    expect(page).to have_no_css(".user-stream-item")
  end
end
