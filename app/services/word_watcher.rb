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

  # This regexp is run in miniracer, and the client JS app
  # Make sure it is compatible with major browsers when changing
  # hint: non-chrome browsers do not support 'lookbehind'
  def self.word_matcher_regexp(action, raise_errors: false)
    words = get_cached_words(action)
    if words
      words = words.map do |w|
        word = word_to_regexp(w)
        word = "(#{word})" if SiteSetting.watched_words_regular_expressions?
        word
      end
      regexp = words.join('|')
      if !SiteSetting.watched_words_regular_expressions?
        regexp = "(#{regexp})"
        regexp = "(?:\\W|^)#{regexp}(?=\\W|$)"
      end
      Regexp.new(regexp, Regexp::IGNORECASE)
    end
  rescue RegexpError => e
    raise if raise_errors
    nil # Admin will be alerted via admin_dashboard_data.rb
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

  def should_block?
    word_matches_for_action?(:block, all_matches: true)
  end

  def word_matches_for_action?(action, all_matches: false)
    regexp = self.class.word_matcher_regexp(action)
    if regexp
      match = regexp.match(@raw)
      return match if !all_matches || !match

      if SiteSetting.watched_words_regular_expressions?
        set = Set.new
        @raw.scan(regexp).each do |m|
          if Array === m
            set.add(m.find(&:present?))
          elsif String === m
            set.add(m)
          end
        end
        matches = set.to_a
      else
        matches = @raw.scan(regexp)
        matches.flatten!
        matches.uniq!
      end
      matches.compact!
      matches.sort!
      matches
    else
      false
    end
  end
end
