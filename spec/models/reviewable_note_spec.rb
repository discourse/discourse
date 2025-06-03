# frozen_string_literal: true

RSpec.describe ReviewableNote do
  let(:admin) { Fabricate(:admin) }
  let(:moderator) { Fabricate(:moderator) }
  let(:user) { Fabricate(:user) }
  let(:reviewable) { Fabricate(:reviewable_flagged_post) }

  describe "associations" do
    it { is_expected.to belong_to(:reviewable) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:reviewable_note, reviewable: reviewable, user: admin) }

    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:reviewable_id) }
    it { is_expected.to validate_presence_of(:user_id) }

    context "when content is blank" do
      it "is invalid with empty content" do
        note = build(:reviewable_note, content: "", reviewable: reviewable, user: admin)
        expect(note).not_to be_valid
        expect(note.errors[:content]).to include("can't be blank")
      end

      it "is invalid with whitespace-only content" do
        note = build(:reviewable_note, content: "   ", reviewable: reviewable, user: admin)
        expect(note).not_to be_valid
        expect(note.errors[:content]).to include("can't be blank")
      end
    end
  end

  describe "scopes" do
    let!(:old_note) do
      Fabricate(:reviewable_note, reviewable: reviewable, user: admin, created_at: 2.days.ago)
    end
    let!(:new_note) do
      Fabricate(:reviewable_note, reviewable: reviewable, user: moderator, created_at: 1.day.ago)
    end

    describe ".ordered" do
      it "returns notes ordered by creation date ascending" do
        notes = ReviewableNote.ordered
        expect(notes.first).to eq(old_note)
        expect(notes.last).to eq(new_note)
      end
    end
  end

  describe "staff permission check" do
    it "allows staff users to create notes (permission checked in controller)" do
      admin_note = build(:reviewable_note, reviewable: reviewable, user: admin)
      expect(admin_note.save).to be_truthy

      moderator_note = build(:reviewable_note, reviewable: reviewable, user: moderator)
      expect(moderator_note.save).to be_truthy
    end

    it "allows regular users to create notes at model level (permission enforced in controller)" do
      # Model doesn't enforce staff requirement - that's done in controller
      note = build(:reviewable_note, reviewable: reviewable, user: user)
      expect(note.save).to be_truthy
    end

    it "prevents creation when user is nil" do
      note = build(:reviewable_note, reviewable: reviewable, user: nil)
      expect(note.save).to be_falsey
      expect(note.errors[:user_id]).to include("can't be blank")
    end
  end

  describe "factory" do
    it "creates a valid reviewable note" do
      note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)
      expect(note).to be_valid
      expect(note.content).to be_present
      expect(note.reviewable).to eq(reviewable)
      expect(note.user).to eq(admin)
    end
  end

  describe "content handling" do
    it "preserves line breaks in content" do
      content_with_breaks = "Line 1\nLine 2\n\nLine 4"
      note =
        Fabricate(
          :reviewable_note,
          content: content_with_breaks,
          reviewable: reviewable,
          user: admin,
        )
      expect(note.content).to eq(content_with_breaks)
    end

    it "handles unicode characters" do
      unicode_content = "This is a note with emojis 🎉 and accented characters café"
      note =
        Fabricate(:reviewable_note, content: unicode_content, reviewable: reviewable, user: admin)
      expect(note.content).to eq(unicode_content)
    end
  end

  describe "timestamps" do
    it "sets created_at and updated_at on creation" do
      note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)
      expect(note.created_at).to be_present
      expect(note.updated_at).to be_present
    end

    it "updates updated_at when content is changed" do
      note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)
      original_updated_at = note.updated_at

      sleep(0.01) # Ensure time difference
      note.update!(content: "Updated content")

      expect(note.updated_at).to be > original_updated_at
    end
  end
end
