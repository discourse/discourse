# frozen_string_literal: true

RSpec.describe BookmarksController do
  let(:current_user) { Fabricate(:user) }
  let(:user_2) { Fabricate(:user) }
  let(:bookmark_post) { Fabricate(:post) }
  let(:bookmark_post_2) { Fabricate(:post) }
  let(:bookmark_topic) { Fabricate(:topic) }
  let(:bookmark_user) { current_user }

  describe "#create" do
    before { sign_in(current_user) }

    it "rate limits creates" do
      SiteSetting.max_bookmarks_per_day = 1
      RateLimiter.enable

      post "/bookmarks.json",
           params: {
             bookmarkable_id: bookmark_post.id,
             bookmarkable_type: "Post",
             reminder_at: (Time.zone.now + 1.day).iso8601,
           }

      expect(response.status).to eq(200)

      post "/bookmarks.json",
           params: {
             bookmarkable_id: bookmark_post.id,
             bookmarkable_type: "Post",
           }
      expect(response.status).to eq(429)
    end

    context "if the user reached the max bookmark limit" do
      before { SiteSetting.max_bookmarks_per_user = 1 }

      it "returns failed JSON with a 400 error" do
        post "/bookmarks.json",
             params: {
               bookmarkable_id: bookmark_post.id,
               bookmarkable_type: "Post",
               reminder_at: (Time.zone.now + 1.day).iso8601,
             }
        post "/bookmarks.json",
             params: {
               bookmarkable_id: bookmark_post.id,
               bookmarkable_type: "Post",
             }

        expect(response.status).to eq(400)
        user_bookmarks_url = "#{Discourse.base_url}/my/activity/bookmarks"
        expect(response.parsed_body["errors"]).to include(
          I18n.t(
            "bookmarks.errors.too_many",
            user_bookmarks_url: user_bookmarks_url,
            limit: SiteSetting.max_bookmarks_per_user,
          ),
        )
      end
    end

    context "if the user already has bookmarked the record" do
      before do
        Fabricate(:bookmark, bookmarkable: bookmark_post, user: bookmark_user)
        Fabricate(:bookmark, bookmarkable: bookmark_topic, user: bookmark_user)
      end

      it "returns failed JSON with a 400 error" do
        post "/bookmarks.json",
             params: {
               bookmarkable_id: bookmark_post.id,
               bookmarkable_type: "Post",
               reminder_at: (Time.zone.now + 1.day).iso8601,
             }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("bookmarks.errors.already_bookmarked", type: "Post"),
        )

        post "/bookmarks.json",
             params: {
               bookmarkable_id: bookmark_topic.id,
               bookmarkable_type: "Topic",
               reminder_at: (Time.zone.now + 1.day).iso8601,
             }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("bookmarks.errors.already_bookmarked", type: "Topic"),
        )
      end
    end
  end

  describe "#destroy" do
    before { sign_in(current_user) }

    let!(:bookmark) { Fabricate(:bookmark, bookmarkable: bookmark_post, user: bookmark_user) }

    it "destroys the bookmark" do
      delete "/bookmarks/#{bookmark.id}.json"
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
    end

    it "returns an indication of whether there are still bookmarks in the topic" do
      delete "/bookmarks/#{bookmark.id}.json"
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(response.parsed_body["topic_bookmarked"]).to eq(false)
      bm2 =
        Fabricate(
          :bookmark,
          user: bookmark_user,
          bookmarkable: Fabricate(:post, topic: bookmark_post.topic),
        )
      bm3 = Fabricate(:bookmark, user: bookmark_user, bookmarkable: bookmark_post.topic)
      delete "/bookmarks/#{bm2.id}.json"
      expect(Bookmark.find_by(id: bm2.id)).to eq(nil)
      expect(response.parsed_body["topic_bookmarked"]).to eq(true)
      delete "/bookmarks/#{bm3.id}.json"
      expect(Bookmark.find_by(id: bm3.id)).to eq(nil)
      expect(response.parsed_body["topic_bookmarked"]).to eq(false)
    end

    context "if the bookmark has already been destroyed" do
      it "returns failed JSON with a 403 error" do
        bookmark.destroy!
        delete "/bookmarks/#{bookmark.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"].first).to include(I18n.t("not_found"))
      end
    end

    context "if the bookmark does not belong to the user" do
      let(:bookmark_user) { Fabricate(:user) }

      it "returns failed JSON with a 403 error" do
        delete "/bookmarks/#{bookmark.id}.json"

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"].first).to include(I18n.t("invalid_access"))
      end
    end
  end

  describe "#bulk" do
    it "needs you to be logged in" do
      put "/bookmarks/bulk.json"
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      before { sign_in(bookmark_user) }

      let!(:bookmark) { Fabricate(:bookmark, bookmarkable: bookmark_post, user: bookmark_user) }
      let!(:bookmark_2) { Fabricate(:bookmark, bookmarkable: bookmark_post_2, user: bookmark_user) }

      let!(:operation) { { type: "clear_reminder" } }
      let!(:bookmark_ids) { [bookmark.id, bookmark_2.id] }

      it "requires a list of bookmark_ids" do
        put "/bookmarks/bulk.json", params: { operation: operation }
        expect(response.status).to eq(400)
      end

      it "requires an operation param" do
        put "/bookmarks/bulk.json", params: { bookmark_ids: bookmark_ids }
        expect(response.status).to eq(400)
      end

      it "can clear reminder for the given bookmarks" do
        expect do
          put "/bookmarks/bulk.json",
              params: {
                operation: {
                  type: "clear_reminder",
                },
                bookmark_ids: [bookmark.id],
              }
          expect(response.status).to eq(200)
        end.to change { Bookmark.find(bookmark.id).reminder_set_at }.to(nil)
      end

      it "can delete bookmarks" do
        expect do
          put "/bookmarks/bulk.json",
              params: {
                operation: {
                  type: "delete",
                },
                bookmark_ids: [bookmark.id, bookmark_2.id],
              }

          expect(response.status).to eq(200)
        end.to change { Bookmark.where(id: [bookmark, bookmark_2]).count }.from(2).to(0)
      end
    end

    describe "can't update other user's bookmarks" do
      before { sign_in(user_2) }

      let!(:bookmark) { Fabricate(:bookmark, bookmarkable: bookmark_post, user: bookmark_user) }
      let!(:bookmark_2) { Fabricate(:bookmark, bookmarkable: bookmark_post_2, user: bookmark_user) }

      let!(:operation) { { type: "clear_reminder" } }
      let!(:bookmark_ids) { [bookmark.id, bookmark_2.id] }

      it "CAN'T clear reminder if the bookmark does not belong to the user" do
        expect do
          put "/bookmarks/bulk.json",
              params: {
                operation: {
                  type: "clear_reminder",
                },
                bookmark_ids: [bookmark.id, bookmark_2.id],
              }
          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"].first).to include(I18n.t("invalid_access"))
        end.to_not change { Bookmark.find(bookmark.id).reminder_set_at }
      end

      it "CAN'T delete bookmarks that does not belong to the user" do
        expect do
          put "/bookmarks/bulk.json",
              params: {
                operation: {
                  type: "delete",
                },
                bookmark_ids: [bookmark.id, bookmark_2.id],
              }
          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"].first).to include(I18n.t("invalid_access"))
        end.to_not change { Bookmark.where(id: [bookmark, bookmark_2]).count }.from(2)
      end
    end
  end
end
