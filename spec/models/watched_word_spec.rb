require 'rails_helper'

describe WatchedWord do

  it "can't have duplicate words" do
    Fabricate(:watched_word, word: "darn", action: described_class.actions[:block])
    w = Fabricate.build(:watched_word, word: "darn", action: described_class.actions[:block])
    expect(w.save).to eq(false)
    w = Fabricate.build(:watched_word, word: "darn", action: described_class.actions[:flag])
    expect(w.save).to eq(false)
    expect(described_class.count).to eq(1)
  end

  it "doesn't downcase words" do
    expect(described_class.create(word: "ShooT").word).to eq('ShooT')
  end

  it "strips leading and trailing spaces" do
    expect(described_class.create(word: "  poutine  ").word).to eq('poutine')
  end

  it "squeezes multiple asterisks" do
    expect(described_class.create(word: "a**les").word).to eq('a*les')
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

  describe '#create_or_update_word' do
    it "can create a new record" do
      expect {
        w = described_class.create_or_update_word(word: 'nickelback', action_key: :block)
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
      existing = Fabricate(:watched_word, action: described_class.actions[:flag], created_at: 1.day.ago, updated_at: 1.day.ago)
      expect {
        w = described_class.create_or_update_word(word: existing.word, action_key: :flag)
        expect(w.id).to eq(existing.id)
        expect(w.updated_at).to eq(w.updated_at)
      }.to_not change { described_class.count }
    end

    it "allows action param instead of action_key" do
      expect {
        w = described_class.create_or_update_word(word: 'nickelback', action: described_class.actions[:block])
        expect(w.reload.action).to eq(described_class.actions[:block])
      }.to change { described_class.count }.by(1)
    end

    it "normalizes input" do
      existing = Fabricate(:watched_word, action: described_class.actions[:flag])
      expect {
        w = described_class.create_or_update_word(word: "  #{existing.word.upcase}  ", action_key: :block)
        expect(w.reload.action).to eq(described_class.actions[:block])
        expect(w.id).to eq(existing.id)
      }.to_not change { described_class.count }
    end
  end
end
