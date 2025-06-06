# frozen_string_literal: true

RSpec.describe ReviewableNote do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post) }

  describe "associations" do
    it { is_expected.to belong_to(:reviewable) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:reviewable_note, reviewable: reviewable, user: admin) }

    it { is_expected.to validate_presence_of(:content) }
    it do
      is_expected.to validate_length_of(:content).is_at_least(1).is_at_most(
        ReviewableNote::MAX_CONTENT_LENGTH,
      )
    end
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

    context "when content is too long" do
      it "is invalid with content over #{ReviewableNote::MAX_CONTENT_LENGTH} characters" do
        long_content = "a" * (ReviewableNote::MAX_CONTENT_LENGTH + 1)
        note = build(:reviewable_note, content: long_content, reviewable: reviewable, user: admin)
        expect(note).not_to be_valid
        expect(note.errors[:content]).to include(
          "is too long (maximum is #{ReviewableNote::MAX_CONTENT_LENGTH} characters)",
        )
      end

      it "is valid with content at exactly #{ReviewableNote::MAX_CONTENT_LENGTH} characters" do
        max_content = "a" * ReviewableNote::MAX_CONTENT_LENGTH
        note = build(:reviewable_note, content: max_content, reviewable: reviewable, user: admin)
        expect(note).to be_valid
      end
    end
  end

  describe "scopes" do
    fab!(:old_note) do
      Fabricate(:reviewable_note, reviewable: reviewable, user: admin, created_at: 2.days.ago)
    end
    fab!(:new_note) do
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

  describe "factory" do
    it "creates a valid reviewable note" do
      note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)
      expect(note).to be_valid
      expect(note.content).to be_present
      expect(note.reviewable).to eq(reviewable)
      expect(note.user).to eq(admin)
    end
  end
end
