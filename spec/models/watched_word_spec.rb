# frozen_string_literal: true

RSpec.describe WatchedWord do
  it "can't have duplicate words" do
    Fabricate(:watched_word, word: "darn", action: described_class.actions[:block])
    w = Fabricate.build(:watched_word, word: "darn", action: described_class.actions[:block])
    expect(w.save).to eq(false)
    w = Fabricate.build(:watched_word, word: "darn", action: described_class.actions[:flag])
    expect(w.save).to eq(false)
    expect(described_class.count).to eq(1)
  end

  it "doesn't downcase words" do
    expect(described_class.create(word: "ShooT").word).to eq("ShooT")
  end

  it "strips leading and trailing spaces" do
    expect(described_class.create(word: "  poutine  ").word).to eq("poutine")
  end

  it "squeezes multiple asterisks" do
    expect(described_class.create(word: "a**les").word).to eq("a*les")
  end

  it "is case-insensitive by default" do
    expect(described_class.create(word: "Jest").case_sensitive?).to eq(false)
  end

  it "limits the number of characters in a word" do
    w = Fabricate.build(:watched_word, word: "a" * 101)
    expect(w).to_not be_valid
    expect(w.errors[:word]).to be_present
  end

  it "limits the number of characters in a replacement" do
    w = Fabricate.build(:watched_word, replacement: "a" * 101)
    expect(w).to_not be_valid
    expect(w.errors[:replacement]).to be_present
  end

  describe "action_key=" do
    let(:w) { WatchedWord.new(word: "troll") }

    it "sets action attr from symbol" do
      described_class.actions.keys.each do |k|
        w.action_key = k
        expect(w.action).to eq(described_class.actions[k])
      end
    end

    it "sets action attr from string" do
      described_class.actions.keys.each do |k|
        w.action_key = k.to_s
        expect(w.action).to eq(described_class.actions[k])
      end
    end

    it "sets error for invalid key" do
      w.action_key = "shame"
      expect(w).to_not be_valid
      expect(w.errors[:action]).to be_present
    end
  end

  describe "#create_or_update_word" do
    it "can create a new record" do
      expect {
        w = described_class.create_or_update_word(word: "nickelback", action_key: :block)
        expect(w.reload.action).to eq(described_class.actions[:block])
      }.to change { described_class.count }.by(1)
    end

    it "can update an existing record with different action" do
      existing = Fabricate(:watched_word, action: described_class.actions[:flag])
      expect {
        w = described_class.create_or_update_word(word: existing.word, action_key: :block)
        expect(w.reload.action).to eq(described_class.actions[:block])
        expect(w.id).to eq(existing.id)
      }.to_not change { described_class.count }
    end

    it "doesn't error for existing record with same action" do
      existing =
        Fabricate(
          :watched_word,
          action: described_class.actions[:flag],
          created_at: 1.day.ago,
          updated_at: 1.day.ago,
        )
      expect {
        w = described_class.create_or_update_word(word: existing.word, action_key: :flag)
        expect(w.id).to eq(existing.id)
        expect(w.updated_at).to eq_time(w.updated_at)
      }.to_not change { described_class.count }
    end

    it "allows action param instead of action_key" do
      expect {
        w =
          described_class.create_or_update_word(
            word: "nickelback",
            action: described_class.actions[:block],
          )
        expect(w.reload.action).to eq(described_class.actions[:block])
      }.to change { described_class.count }.by(1)
    end

    it "normalizes input" do
      existing = Fabricate(:watched_word, action: described_class.actions[:flag])
      expect {
        w =
          described_class.create_or_update_word(
            word: "  #{existing.word.upcase}  ",
            action_key: :block,
          )
        expect(w.reload.action).to eq(described_class.actions[:block])
        expect(w.id).to eq(existing.id)
      }.to_not change { described_class.count }
    end

    it "error when an tag action is created without valid tags" do
      expect {
        described_class.create!(word: "ramones", action: described_class.actions[:tag])
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "replaces link with absolute URL" do
      word = Fabricate(:watched_word, action: described_class.actions[:link], word: "meta1")
      expect(word.replacement).to eq("http://test.localhost/")

      word =
        Fabricate(
          :watched_word,
          action: described_class.actions[:link],
          word: "meta2",
          replacement: "test",
        )
      expect(word.replacement).to eq("http://test.localhost/test")

      word =
        Fabricate(
          :watched_word,
          action: described_class.actions[:link],
          word: "meta3",
          replacement: "/test",
        )
      expect(word.replacement).to eq("http://test.localhost/test")
    end

    it "sets case-sensitivity of a word" do
      word =
        described_class.create_or_update_word(
          word: "joker",
          action_key: :block,
          case_sensitive: true,
        )
      expect(word.case_sensitive?).to eq(true)

      word = described_class.create_or_update_word(word: "free", action_key: :block)
      expect(word.case_sensitive?).to eq(false)
    end

    it "updates case-sensitivity of a word" do
      existing =
        Fabricate(:watched_word, action: described_class.actions[:block], case_sensitive: true)
      updated =
        described_class.create_or_update_word(
          word: existing.word,
          action_key: :block,
          case_sensitive: false,
        )

      expect(updated.case_sensitive?).to eq(false)
    end

    context "when a case-sensitive word already exists" do
      subject(:create_or_update) do
        described_class.create_or_update_word(word: word, action_key: :block, case_sensitive: true)
      end

      fab!(:existing_word) { Fabricate(:watched_word, case_sensitive: true, word: "Meta") }

      context "when providing the exact same word" do
        let(:word) { existing_word.word }

        it "doesn't create a new watched word" do
          expect { create_or_update }.not_to change { described_class.count }
        end

        it "returns the existing watched word" do
          expect(create_or_update).to eq(existing_word)
        end
      end

      context "when providing the same word with a different case" do
        let(:word) { "metA" }

        it "creates a new watched word" do
          expect(create_or_update).not_to eq(existing_word)
        end

        it "returns the new watched word" do
          expect(create_or_update).to have_attributes word: "metA", case_sensitive: true, action: 1
        end
      end
    end
  end
end
