# frozen_string_literal: true

RSpec.describe WatchedWordGroup do
  fab!(:watched_word_group)
  fab!(:watched_word_1) { Fabricate(:watched_word, watched_word_group_id: watched_word_group.id) }
  fab!(:watched_word_2) { Fabricate(:watched_word, watched_word_group_id: watched_word_group.id) }

  describe "#update_membership" do
    it "adds new words to group" do
      words = [watched_word_1.word, watched_word_2.word, "Sssh", "hack3r"]
      old_action = watched_word_group.action
      watched_words_before_update = watched_word_group.watched_words

      expect(watched_words_before_update.size).to eq(2)
      expect(watched_words_before_update.map(&:word)).to contain_exactly(
        watched_word_1.word,
        watched_word_2.word,
      )
      expect(watched_words_before_update.map(&:action).uniq).to contain_exactly(old_action)

      group =
        watched_word_group.update_membership(
          words: words,
          action_key: WatchedWord.actions[watched_word_group.action],
        )

      expect(group.errors).to be_empty

      watched_words = watched_word_group.reload.watched_words

      expect(watched_word_group.action).to eq(old_action)
      expect(watched_words.size).to eq(4)
      expect(watched_words.map(&:word)).to contain_exactly(*words)
      expect(watched_words.map(&:action).uniq).to contain_exactly(old_action)
    end

    it "removes deleted words from group" do
      words = [watched_word_1.word]
      old_action = watched_word_group.action
      watched_words_before_update = watched_word_group.watched_words

      expect(watched_words_before_update.size).to eq(2)
      expect(watched_words_before_update.map(&:word)).to contain_exactly(
        watched_word_1.word,
        watched_word_2.word,
      )
      expect(watched_words_before_update.map(&:action).uniq).to contain_exactly(old_action)

      group =
        watched_word_group.update_membership(
          words: words,
          action_key: WatchedWord.actions[watched_word_group.action],
        )

      expect(group.errors).to be_empty

      watched_words = watched_word_group.reload.watched_words

      expect(watched_words.size).to eq(1)
      expect(watched_words.map(&:word)).to contain_exactly(*words)
      expect(watched_words.map(&:action).uniq).to contain_exactly(old_action)
    end

    it "updates watched word action" do
      words = [watched_word_1.word, watched_word_2.word, "damn", "4sale"]
      old_action = watched_word_group.action
      watched_words_before_update = watched_word_group.watched_words

      expect(old_action).to eq(WatchedWord.actions[:block])
      expect(watched_words_before_update.map(&:action).uniq).to contain_exactly(old_action)

      group = watched_word_group.update_membership(words: words, action_key: :censor)

      expect(group.errors).to be_empty

      watched_words = watched_word_group.reload.watched_words

      expect(watched_words.size).to eq(4)
      expect(watched_words.map(&:word)).to contain_exactly(*words)
      expect(watched_words.map(&:action).uniq).to contain_exactly(WatchedWord.actions[:censor])
      expect(watched_word_group.action).to eq(WatchedWord.actions[:censor])
    end

    it "leaves membership intact if update fails" do
      words = [watched_word_1.word, watched_word_2.word, "a" * 120]
      old_action = watched_word_group.action
      watched_words_before_update = watched_word_group.watched_words

      expect(watched_words_before_update.size).to eq(2)
      expect(watched_words_before_update.map(&:word)).to contain_exactly(
        watched_word_1.word,
        watched_word_2.word,
      )
      expect(watched_words_before_update.map(&:action).uniq).to contain_exactly(old_action)

      group =
        watched_word_group.update_membership(
          words: words,
          action_key: WatchedWord.actions[watched_word_group.action],
        )

      expect(group.errors).not_to be_empty

      watched_words = watched_word_group.reload.watched_words

      expect(watched_word_group.action).to eq(old_action)
      expect(watched_words.size).to eq(2)
      expect(watched_words.map(&:word)).to contain_exactly(watched_word_1.word, watched_word_2.word)
      expect(watched_words.map(&:action).uniq).to contain_exactly(old_action)
    end
  end

  describe ".create_membership" do
    it "creates and groups words" do
      expect do
        words = %w[damn darn]
        group = described_class.create_membership(words: words, action_key: :block)
        expect(group.watched_words.map(&:word)).to contain_exactly(*words)
      end.to change { described_class.count }.by(1)
    end

    it "does not create group with invalid words" do
      expect do
        words = ["damn", "d" * 120]
        group = described_class.create_membership(words: words, action_key: :block)

        expect(group.new_record?).to eq(true)
        expect(WatchedWord.where(word: words)).to be_empty
      end.not_to change { described_class.count }
    end
  end
end
