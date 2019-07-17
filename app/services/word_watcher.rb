# frozen_string_literal: true

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

  def self.get_cached_words(action)
    Discourse.cache.fetch(word_matcher_regexp_key(action), expires_in: 1.day) do
      words_for_action(action).presence
    end
  end

  def self.word_matcher_regexp(action)
    words = get_cached_words(action)
    if words
      words = words.map { |w| word_to_regexp(w) }
      regexp = "(#{words.join('|')})"
      regexp = "(?<!\\w)(#{regexp})(?!\\w)" if !SiteSetting.watched_words_regular_expressions?
      Regexp.new(regexp, Regexp::IGNORECASE)
    end
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
    "watched-words-list:#{action}"
  end

  def self.clear_cache!
    WatchedWord.actions.each do |a, i|
      Discourse.cache.delete word_matcher_regexp_key(a)
    end
  end

  def requires_approval?
    word_matches_for_action?(:require_approval)
  end

  def should_flag?
    word_matches_for_action?(:flag)
  end

  def should_block?(all_matches: false)
    word_matches_for_action?(:block, all_matches: all_matches)
  end

  def word_matches_for_action?(action, all_matches: false)
    regexp = self.class.word_matcher_regexp(action)
    if regexp
      match = regexp.match(@raw)
      return match if !all_matches || !match
      matches = []
      regexps = self.class.get_cached_words(action).map do |w|
        word = self.class.word_to_regexp(w)
        word = "(?<!\\w)(#{word})(?!\\w)" if !SiteSetting.watched_words_regular_expressions?
        Regexp.new(word, Regexp::IGNORECASE)
      end
      regexps.each do |reg|
        if result = reg.match(@raw)
          matches << result[0] if matches.exclude?(result[0])
        end
      end
      matches.sort
    else
      false
    end
  end
end
