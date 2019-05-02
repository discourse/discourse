# frozen_string_literal: true

# Whe use ActiveSupport mb_chars from here to properly support non ascii downcase
# TODO remove when ruby 2.4 lands
require 'active_support/core_ext/string/multibyte'

#
# Given a string, tell us whether or not is acceptable.
#
class TextSentinel

  attr_accessor :text

  ENTROPY_SCALE ||= 0.7

  def initialize(text, opts = nil)
    @opts = opts || {}
    @text = text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end

  def self.body_sentinel(text, opts = {})
    entropy = SiteSetting.body_min_entropy
    if opts[:private_message]
      scale_entropy = SiteSetting.min_personal_message_post_length.to_f / SiteSetting.min_post_length.to_f
      entropy = (entropy * scale_entropy).to_i
      entropy = (SiteSetting.min_personal_message_post_length.to_f * ENTROPY_SCALE).to_i if entropy > SiteSetting.min_personal_message_post_length
    else
      entropy = (SiteSetting.min_post_length.to_f * ENTROPY_SCALE).to_i if entropy > SiteSetting.min_post_length
    end
    TextSentinel.new(text, min_entropy: entropy)
  end

  def self.title_sentinel(text)
    entropy = if SiteSetting.min_topic_title_length > SiteSetting.title_min_entropy
      SiteSetting.title_min_entropy
    else
      (SiteSetting.min_topic_title_length.to_f * ENTROPY_SCALE).to_i
    end
    TextSentinel.new(text, min_entropy: entropy, max_word_length: SiteSetting.title_max_word_length)
  end

  # Entropy is a number of how many unique characters the string needs.
  # Non-ASCII characters are weighted heavier since they contain more "information"
  def entropy
    chars = @text.to_s.strip.split('')
    @entropy ||= chars.pack('M*' * chars.size).gsub("\n", '').split('=').uniq.size
  end

  def valid?
    @text.present? &&
    seems_meaningful? &&
    seems_pronounceable? &&
    seems_unpretentious? &&
    seems_quiet?
  end

  private

  def symbols_regex
    /[\ -\/\[-\`\:-\@\{-\~]/m
  end

  def seems_meaningful?
    # Minimum entropy if entropy check required
    @opts[:min_entropy].blank? || (entropy >= @opts[:min_entropy])
  end

  def seems_pronounceable?
    # At least some non-symbol characters
    # (We don't have a comprehensive list of symbols, but this will eliminate some noise)
    @text.gsub(symbols_regex, '').size > 0
  end

  def skipped_locale
    %w(zh_CN zh_TW ko ja).freeze
  end

  def seems_unpretentious?
    return true if skipped_locale.include?(SiteSetting.default_locale)
    # Don't allow super long words if there is a word length maximum
    @opts[:max_word_length].blank? || @text.split(/\s|\/|-|\.|:/).map(&:size).max <= @opts[:max_word_length]
  end

  def seems_quiet?
    return true if skipped_locale.include?(SiteSetting.default_locale)
    # We don't allow all upper case content
    SiteSetting.allow_uppercase_posts || @text == @text.mb_chars.downcase.to_s || @text != @text.mb_chars.upcase.to_s
  end

end
