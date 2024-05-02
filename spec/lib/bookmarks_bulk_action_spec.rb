# frozen_string_literal: true

RSpec.describe BookmarksBulkAction do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:bookmark_1) { Fabricate(:bookmark) }
  fab!(:bookmark_2) { Fabricate(:bookmark) }

  describe "delete" do
    describe "when user can't delete" do
      it "does NOT delete the bookmarks" do
        Guardian.any_instance.stubs(:can_edit?).returns(false)
        Guardian.any_instance.stubs(:can_delete?).returns(false)

        bba = BookmarksBulkAction.new(user, [bookmark_1.id, bookmark_2.id], type: "delete")
        bba.perform!

        expect(Bookmark.where(id: bookmark_1.id)).to_not be_empty
        expect(Bookmark.where(id: bookmark_2.id)).to_not be_empty
      end
    end

    describe "when user can delete" do
      it "deletes the bookmarks" do
        Guardian.any_instance.stubs(:can_edit?).returns(true)
        Guardian.any_instance.stubs(:can_delete?).returns(true)

        bba = BookmarksBulkAction.new(user, [bookmark_1.id, bookmark_2.id], type: "delete")
        bba.perform!

        expect(Bookmark.where(id: bookmark_1.id)).to be_empty
        expect(Bookmark.where(id: bookmark_2.id)).to be_empty
      end
    end
  end

  describe "clear reminder" do
    fab!(:bookmark_with_reminder) { Fabricate(:bookmark_next_business_day_reminder) }

    describe "when user can't edit" do
      it "does NOT clear the reminder" do
        Guardian.any_instance.stubs(:can_edit?).returns(false)
        Guardian.any_instance.stubs(:can_delete?).returns(false)

        bba = BookmarksBulkAction.new(user, [bookmark_with_reminder], type: "clear_reminder")
        bba.perform!

        expect(Bookmark.find_by_id(bookmark_with_reminder).reminder_set_at).to_not be_nil
      end
    end

    describe "when user can edit" do
      it "deletes the bookmarks" do
        Guardian.any_instance.stubs(:can_edit?).returns(true)
        Guardian.any_instance.stubs(:can_delete?).returns(true)

        expect do
          bba = BookmarksBulkAction.new(user, [bookmark_with_reminder.id], type: "clear_reminder")
          bba.perform!
        end.to change { Bookmark.find_by_id(bookmark_with_reminder.id).reminder_set_at }.to(nil)
      end
    end
  end
end
