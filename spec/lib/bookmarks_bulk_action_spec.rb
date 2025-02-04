# frozen_string_literal: true

RSpec.describe BookmarksBulkAction do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:bookmark_1) { Fabricate(:bookmark, user: user) }
  fab!(:bookmark_2) { Fabricate(:bookmark, user: user) }

  describe "#delete" do
    describe "when user is not the bookmark owner" do
      it "does NOT delete the bookmarks" do
        bba = BookmarksBulkAction.new(user_2, [bookmark_1.id, bookmark_2.id], type: "delete")
        expect { bba.perform! }.to raise_error Discourse::InvalidAccess

        expect(Bookmark.exists?(bookmark_1.id)).to eq(true)
        expect(Bookmark.exists?(bookmark_2.id)).to eq(true)
      end
    end

    describe "when user is the bookmark owner" do
      it "deletes the bookmarks" do
        bba = BookmarksBulkAction.new(user, [bookmark_1.id, bookmark_2.id], type: "delete")
        bba.perform!

        expect(Bookmark.exists?(bookmark_1.id)).to eq(false)
        expect(Bookmark.exists?(bookmark_2.id)).to eq(false)
      end
    end
  end

  describe "#clear_reminder" do
    fab!(:bookmark_with_reminder) { Fabricate(:bookmark_next_business_day_reminder, user: user) }

    describe "when user is not the bookmark owner" do
      it "does not clear the reminder" do
        bba = BookmarksBulkAction.new(user_2, [bookmark_with_reminder], type: "clear_reminder")
        expect { bba.perform! }.to raise_error Discourse::InvalidAccess
        expect(Bookmark.find_by_id(bookmark_with_reminder).reminder_set_at).to_not be_nil
      end
    end

    describe "when user is the bookmark owner" do
      it "clears the bookmark reminders, including expired reminders" do
        expect do
          bba = BookmarksBulkAction.new(user, [bookmark_with_reminder.id], type: "clear_reminder")
          bba.perform!
        end.to change { bookmark_with_reminder.reload.reminder_set_at }.to(nil).and change {
                bookmark_with_reminder.reload.reminder_at
              }.to(nil)
      end
    end
  end
end
