# frozen_string_literal: true

RSpec.describe BookmarksController do
  fab!(:chatters) { Fabricate(:group) }
  let(:current_user) { Fabricate(:user, group_ids: [chatters.id]) }
  let(:bookmark_message) { Fabricate(:chat_message) }
  let(:bookmark_user) { current_user }

  before do
    register_test_bookmarkable(Chat::MessageBookmarkable)
    SiteSetting.chat_allowed_groups = chatters
    sign_in(current_user)
  end

  after { DiscoursePluginRegistry.reset_register!(:bookmarkables) }

  context "when bookmarking a chat message" do
    describe "#create" do
      it "creates the bookmark" do
        post "/bookmarks.json",
             params: {
               bookmarkable_id: bookmark_message.id,
               bookmarkable_type: "Chat::Message",
               reminder_at: (Time.zone.now + 1.day).iso8601,
             }

        expect(response.status).to eq(200)
        expect(Bookmark.find_by(bookmarkable: bookmark_message).user_id).to eq(current_user.id)
      end
    end

    describe "#destroy" do
      let!(:bookmark) { Fabricate(:bookmark, bookmarkable: bookmark_message, user: bookmark_user) }

      it "destroys the bookmark" do
        delete "/bookmarks/#{bookmark.id}.json"

        expect(response.status).to eq(200)
        expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      end
    end
  end
end
