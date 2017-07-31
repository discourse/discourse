class WatchedWordListSerializer < ApplicationSerializer
  attributes :actions, :words

  def actions
    WatchedWord.actions.keys
  end

  def words
    object.map do |word|
      WatchedWordSerializer.new(word, root: false)
    end
  end
end
