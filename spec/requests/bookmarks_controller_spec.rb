# frozen_string_literal: true

describe BookmarksController do
  let(:current_user) { Fabricate(:user) }
  let(:bookmark_post) { Fabricate(:post) }
  let(:bookmark_topic) { Fabricate(:topic) }
  let(:bookmark_user) { current_user }

  before do
    sign_in(current_user)
  end

  describe "#create" do
    it "rate limits creates" do
      SiteSetting.max_bookmarks_per_day = 1
      RateLimiter.enable
      RateLimiter.clear_all!

      post "/bookmarks.json", params: {
        post_id: bookmark_post.id,
        reminder_at: (Time.zone.now + 1.day).iso8601
      }

      expect(response.status).to eq(200)

      post "/bookmarks.json", params: {
        post_id: Fabricate(:post).id
      }
      expect(response.status).to eq(429)
    end

    # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
    it "creates a for_topic bookmark" do
      post "/bookmarks.json", params: {
        post_id: bookmark_post.id,
        reminder_type: "tomorrow",
        reminder_at: (Time.zone.now + 1.day).iso8601,
        for_topic: true
      }
      expect(response.status).to eq(200)
      bookmark = Bookmark.find(response.parsed_body["id"])
      expect(bookmark.for_topic).to eq(true)
    end

    # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
    it "errors when trying to create a for_topic bookmark for post_number > 1" do
      post "/bookmarks.json", params: {
        post_id: Fabricate(:post, topic: bookmark_post.topic).id,
        reminder_type: "tomorrow",
        reminder_at: (Time.zone.now + 1.day).iso8601,
        for_topic: true
      }
      expect(response.status).to eq(400)
      expect(response.parsed_body['errors']).to include(
        I18n.t("bookmarks.errors.for_topic_must_use_first_post")
      )
    end

    context "if the user reached the max bookmark limit" do
      before do
        SiteSetting.max_bookmarks_per_user = 1
      end

      it "returns failed JSON with a 400 error" do
        post "/bookmarks.json", params: {
          post_id: bookmark_post.id,
          reminder_at: (Time.zone.now + 1.day).iso8601
        }
        post "/bookmarks.json", params: {
          post_id: Fabricate(:post).id
        }

        expect(response.status).to eq(400)
        user_bookmarks_url = "#{Discourse.base_url}/my/activity/bookmarks"
        expect(response.parsed_body['errors']).to include(
          I18n.t("bookmarks.errors.too_many", user_bookmarks_url: user_bookmarks_url, limit: SiteSetting.max_bookmarks_per_user)
        )
      end
    end

    context "if the user already has bookmarked the post" do
      before do
        Fabricate(:bookmark, post: bookmark_post, user: bookmark_user)
      end

      it "returns failed JSON with a 400 error" do
        post "/bookmarks.json", params: {
          post_id: bookmark_post.id,
          reminder_at: (Time.zone.now + 1.day).iso8601
        }

        expect(response.status).to eq(400)
        expect(response.parsed_body['errors']).to include(
          I18n.t("bookmarks.errors.already_bookmarked_post")
        )
      end
    end

    context "if the user already has bookmarked the record (polymorphic)" do
      before do
        SiteSetting.use_polymorphic_bookmarks = true
        Fabricate(:bookmark, bookmarkable: bookmark_post, user: bookmark_user)
        Fabricate(:bookmark, bookmarkable: bookmark_topic, user: bookmark_user)
      end

      it "returns failed JSON with a 400 error" do
        post "/bookmarks.json", params: {
          bookmarkable_id: bookmark_post.id,
          bookmarkable_type: "Post",
          reminder_at: (Time.zone.now + 1.day).iso8601
        }

        expect(response.status).to eq(400)
        expect(response.parsed_body['errors']).to include(
          I18n.t("bookmarks.errors.already_bookmarked", type: "Post")
        )

        post "/bookmarks.json", params: {
          bookmarkable_id: bookmark_topic.id,
          bookmarkable_type: "Topic",
          reminder_at: (Time.zone.now + 1.day).iso8601
        }

        expect(response.status).to eq(400)
        expect(response.parsed_body['errors']).to include(
          I18n.t("bookmarks.errors.already_bookmarked", type: "Topic")
        )
      end
    end
  end

  describe "#destroy" do
    let!(:bookmark) { Fabricate(:bookmark, post: bookmark_post, user: bookmark_user) }

    it "destroys the bookmark" do
      delete "/bookmarks/#{bookmark.id}.json"
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
    end

    it "returns an indication of whether there are still bookmarks in the topic" do
      delete "/bookmarks/#{bookmark.id}.json"
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(response.parsed_body["topic_bookmarked"]).to eq(false)
      bm2 = Fabricate(:bookmark, user: bookmark_user, post: Fabricate(:post, topic: bookmark_post.topic))
      Fabricate(:bookmark, user: bookmark_user, post: Fabricate(:post, topic: bookmark_post.topic))
      delete "/bookmarks/#{bm2.id}.json"
      expect(Bookmark.find_by(id: bm2.id)).to eq(nil)
      expect(response.parsed_body["topic_bookmarked"]).to eq(true)
    end

    context "for polymorphic bookmarks" do
      let!(:bookmark) { Fabricate(:bookmark, bookmarkable: bookmark_post, user: bookmark_user) }

      before do
        SiteSetting.use_polymorphic_bookmarks = true
      end

      it "returns an indication of whether there are still bookmarks in the topic" do
        delete "/bookmarks/#{bookmark.id}.json"
        expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
        expect(response.parsed_body["topic_bookmarked"]).to eq(false)
        bm2 = Fabricate(:bookmark, user: bookmark_user, bookmarkable: Fabricate(:post, topic: bookmark_post.topic))
        bm3 = Fabricate(:bookmark, user: bookmark_user, bookmarkable: bookmark_post.topic)
        delete "/bookmarks/#{bm2.id}.json"
        expect(Bookmark.find_by(id: bm2.id)).to eq(nil)
        expect(response.parsed_body["topic_bookmarked"]).to eq(true)
        delete "/bookmarks/#{bm3.id}.json"
        expect(Bookmark.find_by(id: bm3.id)).to eq(nil)
        expect(response.parsed_body["topic_bookmarked"]).to eq(false)
      end
    end

    context "if the bookmark has already been destroyed" do
      it "returns failed JSON with a 403 error" do
        bookmark.destroy!
        delete "/bookmarks/#{bookmark.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body['errors'].first).to include(
          I18n.t("not_found")
        )
      end
    end

    context "if the bookmark does not belong to the user" do
      let(:bookmark_user) { Fabricate(:user) }

      it "returns failed JSON with a 403 error" do
        delete "/bookmarks/#{bookmark.id}.json"

        expect(response.status).to eq(403)
        expect(response.parsed_body['errors'].first).to include(
          I18n.t("invalid_access")
        )
      end
    end
  end
end
