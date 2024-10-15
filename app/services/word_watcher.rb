# frozen_string_literal: true

class WordWatcher
  REPLACEMENT_LETTER = CGI.unescape_html("&#9632;")
  CACHE_VERSION = 3

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

  def self.cache_key(action)
    "watched-words-list:v#{CACHE_VERSION}:#{action}"
  end

  def self.clear_cache!
    WatchedWord.actions.each { |action, _| Discourse.cache.delete(cache_key(action)) }
  end

  def self.words_for_action(action)
    WatchedWord
      .where(action: WatchedWord.actions[action.to_sym])
      .limit(WatchedWord::MAX_WORDS_PER_ACTION)
      .order(:id)
      .pluck(:word, :replacement, :case_sensitive, :html)
      .to_h do |w, r, c, h|
        opts = { word: w, replacement: r, case_sensitive: c }.compact
        opts[:html] = true if h
        [word_to_regexp(w, match_word: false), opts]
      end
  end

  def self.words_for_action_exist?(action)
    WatchedWord.where(action: WatchedWord.actions[action.to_sym]).exists?
  end

  def self.cached_words_for_action(action)
    if cache_enabled?
      Discourse
        .cache
        .fetch(cache_key(action), expires_in: 1.day) { words_for_action(action).presence }
    else
      words_for_action(action).presence
    end
  end

  def self.regexps_for_action(action, engine: :ruby)
    cached_words_for_action(action)&.to_h do |_, attrs|
      [word_to_regexp(attrs[:word], engine: engine), attrs]
    end
  end

  # This regexp is run in miniracer, and the client JS app
  # Make sure it is compatible with major browsers when changing
  # hint: non-chrome browsers do not support 'lookbehind'
  def self.compiled_regexps_for_action(action, engine: :ruby, raise_errors: false)
    words = cached_words_for_action(action)
    return [] if words.blank?

    words
      .values
      .group_by { |attrs| attrs[:case_sensitive] ? :case_sensitive : :case_insensitive }
      .map do |group_key, attrs_list|
        words = attrs_list.map { |attrs| attrs[:word] }

        # Compile all watched words into a single regular expression
        regexp =
          words
            .map do |word|
              r = word_to_regexp(word, match_word: SiteSetting.watched_words_regular_expressions?)
              begin
                r if Regexp.new(r)
              rescue RegexpError
                raise if raise_errors
              end
            end
            .select { |r| r.present? }
            .join("|")

        # Add word boundaries to the regexp for regular watched words
        regexp =
          match_word_regexp(
            regexp,
            engine: engine,
          ) if !SiteSetting.watched_words_regular_expressions?

        # Add case insensitive flag if needed
        Regexp.new(regexp, group_key == :case_sensitive ? nil : Regexp::IGNORECASE)
      end
  end

  def self.serialized_regexps_for_action(action, engine: :ruby)
    compiled_regexps_for_action(action, engine: engine).map do |r|
      { r.source => { case_sensitive: !r.casefold? } }
    end
  end

  def self.word_to_regexp(word, engine: :ruby, match_word: true)
    if SiteSetting.watched_words_regular_expressions?
      regexp = word
      regexp = "(#{regexp})" if match_word
      regexp
    else
      # Convert word to regex by escaping special characters in a regexp.
      # Avoid using Regexp.escape because it escapes more characters than
      # it should (for example, whitespaces, dashes, etc)
      regexp = word.gsub(/([.*+?^${}()|\[\]\\])/, '\\\\\1')

      # Convert wildcards to regexp
      regexp = regexp.gsub("\\*", '\S*')

      regexp = match_word_regexp(regexp, engine: engine) if match_word
      regexp
    end
  end

  def self.censor(html)
    regexps = compiled_regexps_for_action(:censor)
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

    regexps = compiled_regexps_for_action(:censor)
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
    regexps = self.class.compiled_regexps_for_action(action)
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
    options = case_sensitive ? nil : Regexp::IGNORECASE
    Regexp.new(WordWatcher.word_to_regexp(word), options).match?(@raw)
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

  # Returns a regexp that transforms a regular expression into a regular
  # expression that matches a whole word.
  def self.match_word_regexp(regexp, engine: :ruby)
    if engine == :js
      "(?:\\P{L}|^)(#{regexp})(?=\\P{L}|$)"
    elsif engine == :ruby
      "(?:[^[:word:]]|^)(#{regexp})(?=[^[:word:]]|$)"
    else
      raise "unknown regexp engine: #{engine}"
    end
  end

  private_class_method :match_word_regexp

  def self.replace(text, watch_word_type)
    regexps_for_action(watch_word_type)
      .to_a
      .reduce(text) do |t, (word_regexp, attrs)|
        case_flag = attrs[:case_sensitive] ? nil : Regexp::IGNORECASE
        replace_text_with_regexp(t, Regexp.new(word_regexp, case_flag), attrs[:replacement])
      end
  end

  private_class_method :replace
end
