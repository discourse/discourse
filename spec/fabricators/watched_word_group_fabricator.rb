# frozen_string_literal: true

Fabricator(:watched_word_group) do
  action WatchedWord.actions[:block]
  watched_words { [Fabricate.build(:watched_word)] }
end
