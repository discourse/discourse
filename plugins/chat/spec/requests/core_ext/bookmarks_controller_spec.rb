# frozen_string_literal: true

RSpec.describe BookmarksController do
  fab!(:chatters, :group)
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
               reminder_at: 1.day.from_now.iso8601,
             }

        expect(response.status).to eq(200)
        expect(Bookmark.find_by(bookmarkable: bookmark_message).user_id).to eq(current_user.id)
      end

      it "does not create a bookmark for a reply whose thread original message was trashed" do
        thread_channel = Fabricate(:category_channel, threading_enabled: true)
        original_message =
          Fabricate(:chat_message, chat_channel: thread_channel, message: "thread original secret")
        thread =
          Fabricate(:chat_thread, channel: thread_channel, original_message: original_message)
        reply =
          Fabricate(
            :chat_message,
            chat_channel: thread_channel,
            thread: thread,
            message: "thread reply secret",
          )
        original_message.trash!

        post "/bookmarks.json",
             params: {
               bookmarkable_id: reply.id,
               bookmarkable_type: "Chat::Message",
             }

        expect(response.status).to eq(403)
        expect(Bookmark.exists?(bookmarkable: reply)).to eq(false)
      end

      it "does not return a bookmarked reply after its thread original message was trashed" do
        thread_channel = Fabricate(:category_channel, threading_enabled: true)
        thread_channel.add(current_user)
        original_message =
          Fabricate(:chat_message, chat_channel: thread_channel, message: "thread original secret")
        thread =
          Fabricate(:chat_thread, channel: thread_channel, original_message: original_message)
        reply =
          Fabricate(
            :chat_message,
            chat_channel: thread_channel,
            thread: thread,
            message: "thread reply secret",
          )
        Fabricate(:bookmark, user: current_user, bookmarkable: reply)

        get "/u/#{current_user.username}/bookmarks.json"
        expect(response.status).to eq(200)
        expect(response.body).to include("thread reply secret")

        original_message.trash!

        get "/u/#{current_user.username}/bookmarks.json"
        expect(response.status).to eq(200)
        expect(response.body).not_to include("thread reply secret")
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
