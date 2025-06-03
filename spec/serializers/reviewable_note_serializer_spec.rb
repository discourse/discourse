# frozen_string_literal: true

RSpec.describe ReviewableNoteSerializer do
  let(:admin) { Fabricate(:admin) }
  let(:moderator) { Fabricate(:moderator) }
  let(:user) { Fabricate(:user) }
  let(:reviewable) { Fabricate(:reviewable_flagged_post) }
  let(:note) do
    Fabricate(:reviewable_note, reviewable: reviewable, user: admin, content: "Test note content")
  end

  def serialized_note(note, current_user = admin)
    ReviewableNoteSerializer.new(note, scope: Guardian.new(current_user), root: false).as_json
  end

  describe "serialization" do
    let(:json) { serialized_note(note) }

    it "includes basic attributes" do
      expect(json[:id]).to eq(note.id)
      expect(json[:content]).to eq("Test note content")
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end

    it "includes user information" do
      expect(json[:user]).to be_present
      expect(json[:user][:id]).to eq(admin.id)
      expect(json[:user][:username]).to eq(admin.username)
    end

    context "with updated note" do
      before { note.update!(content: "Updated content") }

      it "reflects the updated content" do
        json = serialized_note(note)
        expect(json[:content]).to eq("Updated content")
      end

      it "shows different created_at and updated_at" do
        json = serialized_note(note)
        expect(json[:created_at]).not_to eq(json[:updated_at])
      end
    end
  end

  describe "user serialization" do
    context "when note author is admin" do
      let(:json) { serialized_note(note) }

      it "includes admin user information" do
        expect(json[:user][:id]).to eq(admin.id)
        expect(json[:user][:username]).to eq(admin.username)
        expect(json[:user][:name]).to eq(admin.name)
        expect(json[:user][:avatar_template]).to be_present
      end
    end

    context "when note author is moderator" do
      let(:moderator_note) { Fabricate(:reviewable_note, reviewable: reviewable, user: moderator) }
      let(:json) { serialized_note(moderator_note) }

      it "includes moderator user information" do
        expect(json[:user][:id]).to eq(moderator.id)
        expect(json[:user][:username]).to eq(moderator.username)
      end
    end

    context "when user association is nil" do
      before do
        # Simulate a case where user might be nil (though this shouldn't happen in practice)
        allow(note).to receive(:user).and_return(nil)
      end

      it "handles nil user gracefully" do
        json = serialized_note(note)
        expect(json[:user]).to be_nil
      end
    end
  end

  describe "content handling" do
    context "with HTML content" do
      let(:html_note) do
        Fabricate(
          :reviewable_note,
          reviewable: reviewable,
          user: admin,
          content: "<p>HTML <strong>content</strong></p>",
        )
      end

      it "preserves HTML content" do
        json = serialized_note(html_note)
        expect(json[:content]).to eq("<p>HTML <strong>content</strong></p>")
      end
    end

    context "with multiline content" do
      let(:multiline_note) do
        Fabricate(
          :reviewable_note,
          reviewable: reviewable,
          user: admin,
          content: "Line 1\nLine 2\n\nLine 4",
        )
      end

      it "preserves line breaks" do
        json = serialized_note(multiline_note)
        expect(json[:content]).to eq("Line 1\nLine 2\n\nLine 4")
      end
    end

    context "with Unicode content" do
      let(:unicode_note) do
        Fabricate(
          :reviewable_note,
          reviewable: reviewable,
          user: admin,
          content: "Unicode test 🎉 café naïve résumé",
        )
      end

      it "handles Unicode characters correctly" do
        json = serialized_note(unicode_note)
        expect(json[:content]).to eq("Unicode test 🎉 café naïve résumé")
      end
    end

    context "with maximum length content" do
      let(:max_content) { "a" * ReviewableNote::MAX_CONTENT_LENGTH }
      let(:max_note) do
        Fabricate(:reviewable_note, reviewable: reviewable, user: admin, content: max_content)
      end

      it "serializes long content correctly" do
        json = serialized_note(max_note)
        expect(json[:content]).to eq(max_content)
        expect(json[:content].length).to eq(ReviewableNote::MAX_CONTENT_LENGTH)
      end
    end
  end

  describe "permissions and scope" do
    context "when viewed by admin" do
      let(:json) { serialized_note(note, admin) }

      it "serializes all information" do
        expect(json[:id]).to be_present
        expect(json[:content]).to be_present
        expect(json[:user]).to be_present
        expect(json[:created_at]).to be_present
        expect(json[:updated_at]).to be_present
      end
    end

    context "when viewed by moderator" do
      let(:json) { serialized_note(note, moderator) }

      it "serializes all information for moderators" do
        expect(json[:id]).to be_present
        expect(json[:content]).to be_present
        expect(json[:user]).to be_present
        expect(json[:created_at]).to be_present
        expect(json[:updated_at]).to be_present
      end
    end

    context "when viewed by regular user" do
      let(:json) { serialized_note(note, user) }

      it "still serializes information (controller handles permissions)" do
        # The serializer itself doesn't restrict access - that's handled at the controller level
        expect(json[:id]).to be_present
        expect(json[:content]).to be_present
        expect(json[:user]).to be_present
      end
    end
  end

  describe "BasicUserSerializer integration" do
    let(:json) { serialized_note(note) }

    it "uses BasicUserSerializer for user information" do
      user_fields = json[:user].keys

      # BasicUserSerializer should include these fields
      expect(user_fields).to include(:id, :username, :name, :avatar_template)

      # Should not include sensitive fields that aren't in BasicUserSerializer
      expect(user_fields).not_to include(:email, :password_hash)
    end

    it "includes basic user fields from BasicUserSerializer" do
      user_fields = json[:user].keys
      expect(user_fields).to include(:id, :username, :name, :avatar_template)
      # BasicUserSerializer doesn't include admin/moderator status
    end
  end

  describe "serializer inheritance" do
    it "inherits from ApplicationSerializer" do
      expect(ReviewableNoteSerializer.superclass).to eq(ApplicationSerializer)
    end

    it "has the expected attributes defined" do
      expect(ReviewableNoteSerializer._attributes).to include(
        :id,
        :content,
        :created_at,
        :updated_at,
      )
    end

    it "has the user association defined" do
      expect(ReviewableNoteSerializer._associations[:user]).to be_present
      # Note: Association structure may vary - just check it exists
    end
  end

  describe "edge cases" do
    context "with minimal note data" do
      let(:minimal_note) do
        note = ReviewableNote.new
        note.id = 1
        note.content = "Minimal"
        note.created_at = Time.current
        note.updated_at = Time.current
        allow(note).to receive(:user).and_return(admin)
        note
      end

      it "handles minimal data correctly" do
        json = serialized_note(minimal_note)
        expect(json[:id]).to eq(1)
        expect(json[:content]).to eq("Minimal")
        expect(json[:user][:id]).to eq(admin.id)
      end
    end

    context "when timestamps are missing" do
      before do
        allow(note).to receive(:created_at).and_return(nil)
        allow(note).to receive(:updated_at).and_return(nil)
      end

      it "handles nil timestamps" do
        json = serialized_note(note)
        expect(json[:created_at]).to be_nil
        expect(json[:updated_at]).to be_nil
      end
    end
  end
end
