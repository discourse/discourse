# frozen_string_literal: true

class WordWatcher
  REPLACEMENT_LETTER ||= CGI.unescape_html("&#9632;")
  CACHE_VERSION = 2

  def initialize(raw)
    @raw = raw
  end

  @cache_enabled = true

  def self.disable_cache
    @cache_enabled = false
  end

  def self.cache_enabled?
    @cache_enabled
  end

  def self.words_for_action(action)
    WatchedWord
      .where(action: WatchedWord.actions[action.to_sym])
      .limit(WatchedWord::MAX_WORDS_PER_ACTION)
      .order(:id)
      .pluck(:word, :replacement, :case_sensitive)
      .map { |w, r, c| [w, { replacement: r, case_sensitive: c }.compact] }
      .to_h
  end

  def self.words_for_action_exists?(action)
    WatchedWord.where(action: WatchedWord.actions[action.to_sym]).exists?
  end

  def self.get_cached_words(action)
    if cache_enabled?
      Discourse
        .cache
        .fetch(word_matcher_regexp_key(action), expires_in: 1.day) do
          words_for_action(action).presence
        end
    else
      words_for_action(action).presence
    end
  end

  def self.serializable_word_matcher_regexp(action)
    word_matcher_regexp_list(action).map { |r| { r.source => { case_sensitive: !r.casefold? } } }
  end

  # This regexp is run in miniracer, and the client JS app
  # Make sure it is compatible with major browsers when changing
  # hint: non-chrome browsers do not support 'lookbehind'
  def self.word_matcher_regexp_list(action, raise_errors: false)
    words = get_cached_words(action)
    return [] if words.blank?

    grouped_words = { case_sensitive: [], case_insensitive: [] }

    words.each do |w, attrs|
      word = word_to_regexp(w)
      word = "(#{word})" if SiteSetting.watched_words_regular_expressions?

      group_key = attrs[:case_sensitive] ? :case_sensitive : :case_insensitive
      grouped_words[group_key] << word
    end

    regexps = grouped_words.select { |_, w| w.present? }.transform_values { |w| w.join("|") }

    if !SiteSetting.watched_words_regular_expressions?
      regexps.transform_values! { |regexp| "(?:[^[:word:]]|^)(#{regexp})(?=[^[:word:]]|$)" }
    end

    regexps.map { |c, regexp| Regexp.new(regexp, c == :case_sensitive ? nil : Regexp::IGNORECASE) }
  rescue RegexpError
    raise if raise_errors
    [] # Admin will be alerted via admin_dashboard_data.rb
  end

  def self.word_matcher_regexps(action)
    if words = get_cached_words(action)
      words.map { |w, opts| [word_to_regexp(w, whole: true), opts] }.to_h
    end
  end

  def self.word_to_regexp(word, whole: false)
    if SiteSetting.watched_words_regular_expressions?
      # Strip ruby regexp format if present
      regexp = word.start_with?("(?-mix:") ? word[7..-2] : word
      regexp = "(#{regexp})" if whole
      return regexp
    end

    regexp = Regexp.escape(word).gsub("\\*", '\S*')

    if whole && !SiteSetting.watched_words_regular_expressions?
      regexp = "(?:[^[:word:]]|^)(#{regexp})(?=[^[:word:]]|$)"
    end

    regexp
  end

  def self.word_matcher_regexp_key(action)
    "watched-words-list:v#{CACHE_VERSION}:#{action}"
  end

  def self.censor(html)
    regexps = word_matcher_regexp_list(:censor)
    return html if regexps.blank?

    doc = Nokogiri::HTML5.fragment(html)
    doc.traverse do |node|
      regexps.each do |regexp|
        node.content = censor_text_with_regexp(node.content, regexp) if node.text?
      end
    end

    doc.to_s
  end

  def self.censor_text(text)
    return text if text.blank?

    regexps = word_matcher_regexp_list(:censor)
    return text if regexps.blank?

    regexps.inject(text) { |txt, regexp| censor_text_with_regexp(txt, regexp) }
  end

  def self.replace_text(text)
    return text if text.blank?
    replace(text, :replace)
  end

  def self.replace_link(text)
    return text if text.blank?
    replace(text, :link)
  end

  def self.apply_to_text(text)
    text = censor_text(text)
    text = replace_text(text)
    text = replace_link(text)
    text
  end

  def self.clear_cache!
    WatchedWord.actions.each { |a, i| Discourse.cache.delete word_matcher_regexp_key(a) }
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

  def should_silence?
    word_matches_for_action?(:silence)
  end

  def word_matches_for_action?(action, all_matches: false)
    regexps = self.class.word_matcher_regexp_list(action)
    return if regexps.blank?

    match_list = []
    regexps.each do |regexp|
      match = regexp.match(@raw)

      if !all_matches
        return match if match
        next
      end

      next if !match

      if SiteSetting.watched_words_regular_expressions?
        set = Set.new
        @raw
          .scan(regexp)
          .each do |m|
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
      end

      match_list.concat(matches)
    end

    return if match_list.blank?

    match_list.compact!
    match_list.uniq!
    match_list.sort!
    match_list
  end

  def word_matches?(word, case_sensitive: false)
    Regexp.new(
      WordWatcher.word_to_regexp(word, whole: true),
      case_sensitive ? nil : Regexp::IGNORECASE,
    ).match?(@raw)
  end

  def self.replace_text_with_regexp(text, regexp, replacement)
    text.gsub(regexp) do |match|
      prefix = ""
      # match may be prefixed with a non-word character from the non-capturing group
      # Ensure this isn't replaced if watched words regular expression is disabled.
      if !SiteSetting.watched_words_regular_expressions? && (match[0] =~ /\W/) != nil
        prefix = "#{match[0]}"
      end

      "#{prefix}#{replacement}"
    end
  end

  private_class_method :replace_text_with_regexp

  def self.censor_text_with_regexp(text, regexp)
    text.gsub(regexp) do |match|
      # the regex captures leading whitespaces
      padding = match.size - match.lstrip.size
      if padding > 0
        match[0..padding - 1] + REPLACEMENT_LETTER * (match.size - padding)
      else
        REPLACEMENT_LETTER * match.size
      end
    end
  end

  private_class_method :censor_text_with_regexp

  private

  def self.replace(text, watch_word_type)
    word_matcher_regexps(watch_word_type)
      .to_a
      .reduce(text) do |t, (word_regexp, attrs)|
        case_flag = attrs[:case_sensitive] ? nil : Regexp::IGNORECASE
        replace_text_with_regexp(t, Regexp.new(word_regexp, case_flag), attrs[:replacement])
      end
  end
end
