# frozen_string_literal: true

class TextSentinel
  attr_accessor :text

  ENTROPY_SCALE = 0.7

  def initialize(text, opts = nil)
    @opts = opts || {}
    @text = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  end

  def self.body_sentinel(text, opts = {})
    entropy = SiteSetting.body_min_entropy
    if opts[:private_message]
      scale_entropy =
        SiteSetting.min_personal_message_post_length.to_f / SiteSetting.min_post_length.to_f
      entropy = (entropy * scale_entropy).to_i
      entropy =
        (SiteSetting.min_personal_message_post_length.to_f * ENTROPY_SCALE).to_i if entropy >
        SiteSetting.min_personal_message_post_length
    else
      entropy = (SiteSetting.min_post_length.to_f * ENTROPY_SCALE).to_i if entropy >
        SiteSetting.min_post_length
    end
    TextSentinel.new(text, min_entropy: entropy)
  end

  def self.title_sentinel(text)
    entropy =
      if SiteSetting.min_topic_title_length > SiteSetting.title_min_entropy
        SiteSetting.title_min_entropy
      else
        (SiteSetting.min_topic_title_length.to_f * ENTROPY_SCALE).to_i
      end
    TextSentinel.new(text, min_entropy: entropy, max_word_length: SiteSetting.title_max_word_length)
  end

  # Number of unique bytes
  def entropy
    @entropy ||= @text.strip.bytes.uniq.size
  end

  def valid?
    @text.present? && seems_meaningful? && seems_pronounceable? && seems_unpretentious? &&
      seems_quiet?
  end

  # Ensure minumum entropy
  def seems_meaningful?
    @opts[:min_entropy].nil? || entropy >= @opts[:min_entropy]
  end

  # At least one non-symbol character
  def seems_pronounceable?
    @text.match?(/\p{Alnum}/)
  end

  # Ensure maximum word length
  def seems_unpretentious?
    skipped_locales.include?(SiteSetting.default_locale) || @opts[:max_word_length].nil? ||
      !@text.match?(/\p{Alnum}{#{@opts[:max_word_length] + 1},}/)
  end

  # Ensure at least one lowercase letter
  def seems_quiet?
    SiteSetting.allow_uppercase_posts || @text.match?(/\p{Lowercase_Letter}|\p{Other_Letter}/) ||
      !@text.match?(/\p{Letter}/)
  end

  private

  # Hard to tell "word length" for CJK languages
  def skipped_locales
    @skipped_locales ||= %w[ja ko zh_CN zh_TW].freeze
  end
end
