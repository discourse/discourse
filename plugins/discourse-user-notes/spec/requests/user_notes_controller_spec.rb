# frozen_string_literal: true

require "rails_helper"

describe DiscourseUserNotes::UserNotesController do
  fab!(:moderator)
  fab!(:user)
  fab!(:admin)

  before { SiteSetting.user_notes_enabled = true }

  describe "#create" do
    context "when post_id references a PM the moderator cannot see" do
      fab!(:pm_topic) do
        Fabricate(
          :private_message_topic,
          user: admin,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
        )
      end
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: admin) }

      it "does not leak post_url or post_title for the inaccessible post" do
        sign_in(moderator)

        post "/user_notes",
             params: {
               user_note: {
                 user_id: user.id,
                 raw: "probe note",
                 post_id: pm_post.id,
               },
             },
             headers: {
               "ACCEPT" => "application/json",
             }

        expect(response.status).to eq(200)
        json = response.parsed_body
        serialized = json.is_a?(Array) ? json.first : json

        expect(serialized["post_url"]).to be_nil
        expect(serialized["post_title"]).to be_nil

        notes = DiscourseUserNotes.notes_for(user.id)
        expect(notes.last["post_id"]).to be_nil
      end
    end
  end

  describe "#index" do
    context "when a note references a PM the moderator cannot see" do
      fab!(:pm_topic) do
        Fabricate(
          :private_message_topic,
          user: admin,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
        )
      end
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: admin) }

      before { DiscourseUserNotes.add_note(user, "old note", admin.id, post_id: pm_post.id) }

      it "does not leak post_url or post_title for inaccessible posts" do
        sign_in(moderator)

        get "/user_notes", params: { user_id: user.id }, headers: { "ACCEPT" => "application/json" }

        expect(response.status).to eq(200)
        json = response.parsed_body
        note = json["user_notes"].first

        expect(note["post_url"]).to be_nil
        expect(note["post_title"]).to be_nil
      end
    end
  end
end
