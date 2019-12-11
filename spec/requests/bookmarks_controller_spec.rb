# frozen_string_literal: true

require 'rails_helper'

describe BookmarksController do
  let(:current_user) { Fabricate(:user) }
  let(:bookmark_post) { Fabricate(:post) }

  before do
    sign_in(current_user)
  end

  describe "#create" do
    context "if the user already has bookmarked the post" do
      before do
        Fabricate(:bookmark, post: bookmark_post, user: current_user)
      end

      it "returns failed JSON with a 422 error" do
        post "/bookmarks.json", params: {
          post_id: bookmark_post.id,
          reminder_type: "tomorrow",
          reminder_at: (Time.now.utc + 1.day).iso8601
        }

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(
          I18n.t("bookmarks.errors.already_bookmarked_post")
        )
      end
    end

    context "if the user provides a reminder type that needs a reminder_at that is missing" do
      it "returns failed JSON with a 400 error" do
        post "/bookmarks.json", params: {
          post_id: bookmark_post.id,
          reminder_type: "tomorrow"
        }

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)['errors'].first).to include(
          I18n.t("bookmarks.errors.time_must_be_provided", reminder_type: I18n.t("bookmarks.reminders.at_desktop"))
        )
      end
    end
  end
end
