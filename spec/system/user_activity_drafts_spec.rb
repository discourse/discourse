# frozen_string_literal: true

describe "User activity drafts" do
  fab!(:user)
  let(:drafts_page) { PageObjects::Pages::UserActivityDrafts.new }

  before { sign_in(user) }

  describe "bulk selection functionality" do
    before do
      # Create some drafts for testing
      Draft.set(
        user,
        "#{Draft::NEW_TOPIC}_1",
        0,
        { title: "Draft topic 1", reply: "First draft content" }.to_json,
      )
      Draft.set(
        user,
        "#{Draft::NEW_TOPIC}_2",
        0,
        { title: "Draft topic 2", reply: "Second draft content" }.to_json,
      )
      Draft.set(
        user,
        "#{Draft::NEW_TOPIC}_3",
        0,
        { title: "Draft topic 3", reply: "Third draft content" }.to_json,
      )
    end

    it "lets the user select, count, select all, clear, and toggle drafts" do
      drafts_page.visit(user)

      expect(drafts_page).to have_drafts(count: 3)
      expect(drafts_page).to have_bulk_select_checkboxes

      # Initially no bulk controls should be visible
      expect(drafts_page).to have_no_bulk_controls
      expect(drafts_page).to have_checkbox_unchecked(0)

      # Select a draft
      drafts_page.select_draft(0)

      # Now bulk controls should be visible
      expect(drafts_page).to have_bulk_controls
      expect(drafts_page).to have_selected_count(1)
      expect(drafts_page).to have_checkbox_checked(0)
      expect(drafts_page).to have_checkbox_unchecked(1)

      # Select second draft
      drafts_page.select_draft(1)
      expect(drafts_page).to have_selected_count(2)

      # Select third draft
      drafts_page.select_draft(2)
      expect(drafts_page).to have_selected_count(3)

      drafts_page.clear_all_selections
      drafts_page.select_draft(0)
      expect(drafts_page).to have_bulk_controls
      drafts_page.click_bulk_select_all
      expect(drafts_page).to have_selected_count(3)

      # All checkboxes should be checked
      expect(drafts_page).to have_checkbox_checked(0)
      expect(drafts_page).to have_checkbox_checked(1)
      expect(drafts_page).to have_checkbox_checked(2)

      # Clear all selections after select all
      drafts_page.clear_all_selections

      # No checkboxes should be checked and controls should be hidden
      expect(drafts_page).to have_checkbox_unchecked(0)
      expect(drafts_page).to have_checkbox_unchecked(1)
      expect(drafts_page).to have_checkbox_unchecked(2)
      expect(drafts_page).to have_no_bulk_controls

      # Click to select
      drafts_page.select_draft(0)
      expect(drafts_page).to have_checkbox_checked(0)
      expect(drafts_page).to have_bulk_controls

      # Click to deselect
      drafts_page.select_draft(0)
      expect(drafts_page).to have_checkbox_unchecked(0)
      expect(drafts_page).to have_no_bulk_controls
    end

    it "bulk deletes selected drafts" do
      drafts_page.visit(user)

      # Select first two drafts
      drafts_page.select_draft(0)
      drafts_page.select_draft(1)
      expect(drafts_page).to have_selected_count(2)

      # Bulk delete
      drafts_page.click_bulk_delete

      # Confirm deletion in modal
      page.find(".dialog-footer .btn-danger").click

      # Should have only one draft left and no bulk controls
      expect(drafts_page).to have_drafts(count: 1)
      expect(drafts_page).to have_no_bulk_controls
      expect(Draft.count).to eq(1)
    end

    it "clears selection after successful bulk delete" do
      drafts_page.visit(user)

      # Select all drafts
      drafts_page.select_draft(0)
      drafts_page.select_all_drafts
      expect(drafts_page).to have_selected_count(3)

      # Bulk delete all
      drafts_page.click_bulk_delete

      # Confirm deletion
      page.find(".dialog-footer .btn-danger").click

      # Should have no drafts and no controls
      expect(drafts_page).to have_no_drafts
      expect(drafts_page).to have_no_bulk_controls
      expect(Draft.count).to eq(0)
    end
  end

  describe "without bulk selection" do
    it "does not show bulk select controls when no drafts exist" do
      drafts_page.visit(user)

      expect(drafts_page).to have_no_drafts
      expect(drafts_page).to have_no_bulk_select_checkboxes
      expect(drafts_page).to have_no_bulk_controls
    end
  end
end
