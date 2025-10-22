# frozen_string_literal: true

RSpec.describe ReviewableNotesController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:reviewable, :reviewable_flagged_post)

  describe "#create" do
    context "when user is staff" do
      before { sign_in(admin) }

      it "creates a new reviewable note successfully" do
        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "This is a test note",
               },
             }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["content"]).to eq("This is a test note")
        expect(json["user"]["id"]).to eq(admin.id)
        expect(json["user"]["username"]).to eq(admin.username)

        # Verify note was actually created in database
        note = ReviewableNote.last
        expect(note.content).to eq("This is a test note")
        expect(note.user).to eq(admin)
        expect(note.reviewable).to eq(reviewable)
      end

      it "creates a new reviewable note successfully as a moderator" do
        sign_in(moderator)

        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "Moderator note",
               },
             }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["user"]["id"]).to eq(moderator.id)
      end

      it "returns validation errors for invalid content" do
        post "/review/#{reviewable.id}/notes.json", params: { reviewable_note: { content: "" } }

        expect(response.status).to eq(422)

        json = response.parsed_body
        expect(json["errors"]).to include("Content can't be blank")
      end

      it "returns validation errors for content that's too long" do
        long_content = "a" * (ReviewableNote::MAX_CONTENT_LENGTH + 1)

        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: long_content,
               },
             }

        expect(response.status).to eq(422)

        json = response.parsed_body
        expect(json["errors"]).to include(
          "Content is too long (maximum is #{ReviewableNote::MAX_CONTENT_LENGTH} characters)",
        )
      end

      it "trims whitespace from content" do
        post "/review/#{reviewable.id}/notes.json", params: { reviewable_note: { content: "   " } }

        expect(response.status).to eq(422)

        json = response.parsed_body
        expect(json["errors"]).to include("Content can't be blank")
      end

      it "handles missing reviewable" do
        post "/review/999999/notes.json", params: { reviewable_note: { content: "Test note" } }

        expect(response.status).to eq(404)
      end
    end

    context "when user is not staff" do
      before { sign_in(user) }

      it "returns 403" do
        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "This should fail",
               },
             }

        expect(response.status).to eq(403)
      end
    end

    context "when user is not logged in" do
      it "returns 403" do
        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "This should fail",
               },
             }

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#destroy" do
    fab!(:note) { Fabricate(:reviewable_note, reviewable: reviewable, user: admin) }

    context "when user is the note author" do
      before { sign_in(admin) }

      it "deletes the note successfully" do
        expect { delete "/review/#{reviewable.id}/notes/#{note.id}.json" }.to change {
          ReviewableNote.where(user: admin).count
        }.by(-1)

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["success"]).to eq("OK")
      end

      it "returns 404 for non-existent note" do
        delete "/review/#{reviewable.id}/notes/999999.json"
        expect(response.status).to eq(404)
      end
    end

    context "when user is admin but not the note author" do
      fab!(:moderator_note) { Fabricate(:reviewable_note, reviewable: reviewable, user: moderator) }

      before { sign_in(admin) }

      it "allows admin to delete any note" do
        expect { delete "/review/#{reviewable.id}/notes/#{moderator_note.id}.json" }.to change {
          ReviewableNote.count
        }.by(-1)

        expect(response.status).to eq(200)
      end
    end

    context "when user is moderator but not admin and not note author" do
      fab!(:admin_note) { Fabricate(:reviewable_note, reviewable: reviewable, user: admin) }

      before { sign_in(moderator) }

      it "returns 403" do
        delete "/review/#{reviewable.id}/notes/#{admin_note.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user is not staff" do
      before { sign_in(user) }

      it "returns 403" do
        delete "/review/#{reviewable.id}/notes/#{note.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user is not logged in" do
      it "returns 403" do
        delete "/review/#{reviewable.id}/notes/#{note.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when reviewable doesn't exist" do
      before { sign_in(admin) }

      it "returns 404" do
        delete "/review/999999/notes/#{note.id}.json"
        expect(response.status).to eq(404)
      end
    end

    context "when note belongs to different reviewable" do
      fab!(:other_reviewable, :reviewable_flagged_post)
      fab!(:other_note) { Fabricate(:reviewable_note, reviewable: other_reviewable, user: admin) }

      before { sign_in(admin) }

      it "returns 404" do
        delete "/review/#{reviewable.id}/notes/#{other_note.id}.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
