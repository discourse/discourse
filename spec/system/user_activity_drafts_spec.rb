# frozen_string_literal: true

describe "User activity drafts", type: :system do
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

    it "shows bulk select checkboxes for drafts" do
      drafts_page.visit(user)

      expect(drafts_page).to have_drafts(count: 3)
      expect(drafts_page).to have_bulk_select_checkboxes
    end

    it "shows bulk controls only after selecting items" do
      drafts_page.visit(user)

      # Initially no bulk controls should be visible
      expect(drafts_page).to have_no_bulk_controls

      # Select a draft
      drafts_page.select_draft(0)

      # Now bulk controls should be visible
      expect(drafts_page).to have_bulk_controls
      expect(drafts_page).to have_selected_count(1)
    end

    it "updates selection count when selecting multiple drafts" do
      drafts_page.visit(user)

      # Select first draft
      drafts_page.select_draft(0)
      expect(drafts_page).to have_selected_count(1)

      # Select second draft
      drafts_page.select_draft(1)
      expect(drafts_page).to have_selected_count(2)

      # Select third draft
      drafts_page.select_draft(2)
      expect(drafts_page).to have_selected_count(3)
    end

    it "selects all drafts with select all button" do
      drafts_page.visit(user)

      # Select one draft to show controls
      drafts_page.select_draft(0)
      expect(drafts_page).to have_bulk_controls

      # Click select all
      drafts_page.click_bulk_select_all
      expect(drafts_page).to have_selected_count(3)

      # All checkboxes should be checked
      expect(drafts_page).to have_checkbox_checked(0)
      expect(drafts_page).to have_checkbox_checked(1)
      expect(drafts_page).to have_checkbox_checked(2)
    end

    it "clears all selections with clear all button" do
      drafts_page.visit(user)

      # Select all drafts
      drafts_page.select_draft(0)
      drafts_page.select_all_drafts

      # Clear all selections
      drafts_page.clear_all_selections

      # No checkboxes should be checked and controls should be hidden
      expect(drafts_page).to have_checkbox_unchecked(0)
      expect(drafts_page).to have_checkbox_unchecked(1)
      expect(drafts_page).to have_checkbox_unchecked(2)
      expect(drafts_page).to have_no_bulk_controls
    end

    it "shows selected styling on selected items" do
      drafts_page.visit(user)

      # Select first draft
      drafts_page.select_draft(0)

      # First item should have selected styling, second should not
      expect(drafts_page).to have_checkbox_checked(0)
      expect(drafts_page).to have_checkbox_unchecked(1)
    end

    it "toggles selection when clicking checkbox" do
      drafts_page.visit(user)

      # Initially unchecked
      expect(drafts_page).to have_checkbox_unchecked(0)

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
