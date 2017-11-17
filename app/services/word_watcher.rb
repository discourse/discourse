class WordWatcher

  def initialize(raw)
    @raw = raw
  end

  def self.words_for_action(action)
    WatchedWord.where(action: WatchedWord.actions[action.to_sym]).limit(1000).pluck(:word)
  end

  def self.words_for_action_exists?(action)
    WatchedWord.where(action: WatchedWord.actions[action.to_sym]).exists?
  end

  def self.word_matcher_regexp(action)
    s = Discourse.cache.fetch(word_matcher_regexp_key(action), expires_in: 1.day) do
      words = words_for_action(action)
      if words.empty?
        nil
      else
        regexp = '(' + words.map { |w| word_to_regexp(w) }.join('|'.freeze) + ')'
        SiteSetting.watched_words_regular_expressions? ? regexp : "\\b(#{regexp})\\b"
      end
    end
    s.present? ? Regexp.new(s, Regexp::IGNORECASE) : nil
  end

  def self.word_to_regexp(word)
    if SiteSetting.watched_words_regular_expressions?
      # Strip ruby regexp format if present, we're going to make the whole thing
      # case insensitive anyway
      return word.start_with?("(?-mix:") ? word[7..-2] : word
    end
    Regexp.escape(word).gsub("\\*", '\S*')
  end

  def self.word_matcher_regexp_key(action)
    "watched-words-regexp:#{action}"
  end

  def self.clear_cache!
    WatchedWord.actions.sum do |a, i|
      Discourse.cache.delete word_matcher_regexp_key(a)
    end
  end

  def requires_approval?
    word_matches_for_action?(:require_approval)
  end

  def should_flag?
    word_matches_for_action?(:flag)
  end

  def should_block?
    word_matches_for_action?(:block)
  end

  def word_matches_for_action?(action)
    r = self.class.word_matcher_regexp(action)
    r ? r.match(@raw) : false
  end

end
