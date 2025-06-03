# frozen_string_literal: true

RSpec.describe "Reviewable Notes" do
  let(:admin) { Fabricate(:admin) }
  let(:moderator) { Fabricate(:moderator) }
  let(:user) { Fabricate(:user) }
  let(:reviewable) { Fabricate(:reviewable_flagged_post) }

  describe "#create" do
    context "when user is staff" do
      before { sign_in(admin) }

      it "creates a new reviewable note successfully" do
        post "/reviewables/#{reviewable.id}/notes.json",
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

      it "works for moderators too" do
        sign_in(moderator)

        post "/reviewables/#{reviewable.id}/notes.json",
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
        post "/reviewables/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "",
               },
             }

        expect(response.status).to eq(422)

        json = response.parsed_body
        expect(json["errors"]).to include("Content can't be blank")
      end

      it "trims whitespace from content" do
        post "/reviewables/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "   ",
               },
             }

        expect(response.status).to eq(422)

        json = response.parsed_body
        expect(json["errors"]).to include("Content can't be blank")
      end

      it "handles missing reviewable" do
        post "/reviewables/999999/notes.json", params: { reviewable_note: { content: "Test note" } }

        expect(response.status).to eq(404)
      end

      it "handles malformed parameters" do
        post "/reviewables/#{reviewable.id}/notes.json",
             params: {
               wrong_param: {
                 content: "Test note",
               },
             }

        expect(response.status).to eq(400)
      end

      context "with HTML content" do
        it "preserves HTML content as-is" do
          html_content = "<p>This is <strong>bold</strong> text</p>"

          post "/reviewables/#{reviewable.id}/notes.json",
               params: {
                 reviewable_note: {
                   content: html_content,
                 },
               }

          expect(response.status).to eq(200)

          json = response.parsed_body
          expect(json["content"]).to eq(html_content)
        end
      end

      context "with Unicode content" do
        it "handles Unicode characters correctly" do
          unicode_content = "Test with emojis 🎉 and accents café"

          post "/reviewables/#{reviewable.id}/notes.json",
               params: {
                 reviewable_note: {
                   content: unicode_content,
                 },
               }

          expect(response.status).to eq(200)

          json = response.parsed_body
          expect(json["content"]).to eq(unicode_content)
        end
      end
    end

    context "when user is not staff" do
      before { sign_in(user) }

      it "returns 403 forbidden" do
        post "/reviewables/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "This should fail",
               },
             }

        expect(response.status).to eq(403)
      end
    end

    context "when user is not logged in" do
      it "returns 403 forbidden" do
        post "/reviewables/#{reviewable.id}/notes.json",
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
    let!(:note) { Fabricate(:reviewable_note, reviewable: reviewable, user: admin) }

    context "when user is the note author" do
      before { sign_in(admin) }

      it "deletes the note successfully" do
        expect { delete "/reviewables/#{reviewable.id}/notes/#{note.id}.json" }.to change {
          ReviewableNote.count
        }.by(-1)

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["success"]).to eq("OK")
      end

      it "returns 404 for non-existent note" do
        delete "/reviewables/#{reviewable.id}/notes/999999.json"
        expect(response.status).to eq(404)
      end
    end

    context "when user is admin but not the note author" do
      let!(:moderator_note) { Fabricate(:reviewable_note, reviewable: reviewable, user: moderator) }

      before { sign_in(admin) }

      it "allows admin to delete any note" do
        expect {
          delete "/reviewables/#{reviewable.id}/notes/#{moderator_note.id}.json"
        }.to change { ReviewableNote.count }.by(-1)

        expect(response.status).to eq(200)
      end
    end

    context "when user is moderator but not admin and not note author" do
      let!(:admin_note) { Fabricate(:reviewable_note, reviewable: reviewable, user: admin) }

      before { sign_in(moderator) }

      it "returns 403 forbidden" do
        delete "/reviewables/#{reviewable.id}/notes/#{admin_note.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user is not staff" do
      before { sign_in(user) }

      it "returns 403 forbidden" do
        delete "/reviewables/#{reviewable.id}/notes/#{note.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user is not logged in" do
      it "returns 403 forbidden" do
        delete "/reviewables/#{reviewable.id}/notes/#{note.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when reviewable doesn't exist" do
      before { sign_in(admin) }

      it "returns 404" do
        delete "/reviewables/999999/notes/#{note.id}.json"
        expect(response.status).to eq(404)
      end
    end

    context "when note belongs to different reviewable" do
      let(:other_reviewable) { Fabricate(:reviewable_flagged_post) }
      let!(:other_note) { Fabricate(:reviewable_note, reviewable: other_reviewable, user: admin) }

      before { sign_in(admin) }

      it "returns 404" do
        delete "/reviewables/#{reviewable.id}/notes/#{other_note.id}.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "authorization" do
    context "when testing ensure_staff callback" do
      it "blocks non-staff users from accessing create" do
        sign_in(user)

        post "/reviewables/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "Test",
               },
             }

        expect(response.status).to eq(403)
      end

      it "blocks non-staff users from accessing destroy" do
        note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)
        sign_in(user)

        delete "/reviewables/#{reviewable.id}/notes/#{note.id}.json"

        expect(response.status).to eq(403)
      end
    end

    context "when testing requires_login callback" do
      it "blocks anonymous users from accessing create" do
        post "/reviewables/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "Test",
               },
             }

        expect(response.status).to eq(403)
      end

      it "blocks anonymous users from accessing destroy" do
        note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)

        delete "/reviewables/#{reviewable.id}/notes/#{note.id}.json"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "parameter handling" do
    before { sign_in(admin) }

    it "requires reviewable_note parameter for create" do
      post "/reviewables/#{reviewable.id}/notes.json", params: { content: "Missing wrapper param" }

      expect(response.status).to eq(400)
    end

    it "only permits content parameter" do
      post "/reviewables/#{reviewable.id}/notes.json",
           params: {
             reviewable_note: {
               content: "Valid content",
               user_id: user.id, # Should be ignored
               reviewable_id: 999, # Should be ignored
               created_at: 1.day.ago, # Should be ignored
             },
           }

      expect(response.status).to eq(200)

      note = ReviewableNote.last
      expect(note.content).to eq("Valid content")
      expect(note.user).to eq(admin) # Not the user_id from params
      expect(note.reviewable).to eq(reviewable) # Not the reviewable_id from params
    end
  end
end
