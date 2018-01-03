Fabricator(:watched_word) do
  word { sequence(:word) { |i| "word#{i}" } }
  action { WatchedWord.actions[:block] }
end
