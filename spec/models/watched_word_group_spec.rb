# frozen_string_literal: true

RSpec.describe WatchedWordGroup do
  fab!(:watched_word_group)
  let!(:watched_word_1) { watched_word_group.watched_words.first }
  fab!(:watched_word_2) { Fabricate(:watched_word, watched_word_group_id: watched_word_group.id) }

  describe "#create_or_update_members" do
    it "updates watched word action" do
      words = [watched_word_1.word, watched_word_2.word, "damn", "4sale"]
      old_action = watched_word_group.action
      watched_words_before_update = watched_word_group.watched_words

      expect(old_action).to eq(WatchedWord.actions[:block])
      expect(watched_words_before_update.map(&:action).uniq).to contain_exactly(old_action)

      watched_word_group.create_or_update_members(words, action_key: :censor)

      expect(watched_word_group.reload.errors).to be_empty

      watched_words = watched_word_group.watched_words

      expect(watched_words.size).to eq(4)
      expect(watched_words.map(&:word)).to contain_exactly(*words)
      expect(watched_words.map(&:action).uniq).to contain_exactly(WatchedWord.actions[:censor])
      expect(watched_word_group.action).to eq(WatchedWord.actions[:censor])
    end

    it "raises an error if validation fails" do
      words = [watched_word_1.word, watched_word_2.word, "a" * 120]
      old_action = watched_word_group.action
      watched_words_before_update = watched_word_group.watched_words

      expect(watched_words_before_update.size).to eq(2)
      expect(watched_words_before_update.map(&:word)).to contain_exactly(
        watched_word_1.word,
        watched_word_2.word,
      )
      expect(watched_words_before_update.map(&:action).uniq).to contain_exactly(old_action)

      expect {
        watched_word_group.create_or_update_members(
          words,
          action_key: WatchedWord.actions[watched_word_group.action],
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
