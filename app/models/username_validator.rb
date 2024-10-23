# frozen_string_literal: true

class UsernameValidator
  # Public: Perform the validation of a field in a given object
  # it adds the errors (if any) to the object that we're giving as parameter
  #
  # object - Object in which we're performing the validation
  # field_name - name of the field that we're validating
  #
  # Example: UsernameValidator.perform_validation(user, 'name')
  def self.perform_validation(object, field_name)
    validator = UsernameValidator.new(object.public_send(field_name))
    unless validator.valid_format?
      validator.errors.each { |e| object.errors.add(field_name.to_sym, e) }
    end
  end

  def initialize(username)
    @username = username&.unicode_normalize
    @errors = []
  end

  attr_accessor :errors
  attr_reader :username

  def user
    @user ||= User.new(user)
  end

  def valid_format?
    username_present?
    username_length_min?
    username_length_max?
    username_char_valid?
    username_char_allowed?
    username_first_char_valid?
    username_last_char_valid?
    username_no_double_special?
    username_does_not_end_with_confusing_suffix?
    errors.empty?
  end

  CONFUSING_EXTENSIONS = /\.(js|json|css|htm|html|xml|jpg|jpeg|png|gif|bmp|ico|tif|tiff|woff)\z/i
  MAX_CHARS = 60

  ASCII_INVALID_CHAR_PATTERN = /[^\w.-]/
  # All Unicode characters except for alphabetic and numeric character, marks and underscores are invalid.
  # In addition to that, the following letters and nonspacing marks are invalid:
  #   (U+034F) Combining Grapheme Joiner
  #   (U+115F) Hangul Choseong Filler
  #   (U+1160) Hangul Jungseong Filler
  #   (U+17B4) Khmer Vowel Inherent Aq
  #   (U+17B5) Khmer Vowel Inherent Aa
  #   (U+180B - U+180D) Mongolian Free Variation Selectors
  #   (U+3164) Hangul Filler
  #   (U+FFA0) Halfwidth Hangul Filler
  #   (U+FE00 - U+FE0F) "Variation Selectors" block
  #   (U+E0100 - U+E01EF) "Variation Selectors Supplement" block
  UNICODE_INVALID_CHAR_PATTERN =
    /
      [^\p{Alnum}\p{M}._-]|
      [
        \u{034F}
        \u{115F}
        \u{1160}
        \u{17B4}
        \u{17B5}
        \u{180B}-\u{180D}
        \u{3164}
        \u{FFA0}
        \p{In Variation Selectors}
        \p{In Variation Selectors Supplement}
      ]
    /x
  INVALID_LEADING_CHAR_PATTERN = /\A[^\p{Alnum}\p{M}_]+/
  INVALID_TRAILING_CHAR_PATTERN = /[^\p{Alnum}\p{M}]+\z/
  REPEATED_SPECIAL_CHAR_PATTERN = /[-_.]{2,}/

  private

  def username_present?
    return unless errors.empty?

    self.errors << I18n.t(:"user.username.blank") if username.blank?
  end

  def username_length_min?
    return unless errors.empty?

    if username_grapheme_clusters.size < User.username_length.begin
      self.errors << I18n.t(:"user.username.short", count: User.username_length.begin)
    end
  end

  def username_length_max?
    return unless errors.empty?

    if username_grapheme_clusters.size > User.username_length.end
      self.errors << I18n.t(:"user.username.long", count: User.username_length.end)
    elsif username.length > MAX_CHARS
      self.errors << I18n.t(:"user.username.too_long")
    end
  end

  def username_char_valid?
    return unless errors.empty?

    if self.class.invalid_char_pattern.match?(username)
      self.errors << I18n.t(:"user.username.characters")
    end
  end

  def username_char_allowed?
    return unless errors.empty? && self.class.char_allowlist_exists?

    if username.chars.any? { |c| !self.class.allowed_char?(c) }
      self.errors << I18n.t(:"user.username.characters")
    end
  end

  def username_first_char_valid?
    return unless errors.empty?

    if INVALID_LEADING_CHAR_PATTERN.match?(username_grapheme_clusters.first)
      self.errors << I18n.t(:"user.username.must_begin_with_alphanumeric_or_underscore")
    end
  end

  def username_last_char_valid?
    return unless errors.empty?

    if INVALID_TRAILING_CHAR_PATTERN.match?(username_grapheme_clusters.last)
      self.errors << I18n.t(:"user.username.must_end_with_alphanumeric")
    end
  end

  def username_no_double_special?
    return unless errors.empty?

    if REPEATED_SPECIAL_CHAR_PATTERN.match?(username)
      self.errors << I18n.t(:"user.username.must_not_contain_two_special_chars_in_seq")
    end
  end

  def username_does_not_end_with_confusing_suffix?
    return unless errors.empty?

    if CONFUSING_EXTENSIONS.match?(username)
      self.errors << I18n.t(:"user.username.must_not_end_with_confusing_suffix")
    end
  end

  def username_grapheme_clusters
    @username_grapheme_clusters ||= username.grapheme_clusters
  end

  def self.invalid_char_pattern
    SiteSetting.unicode_usernames ? UNICODE_INVALID_CHAR_PATTERN : ASCII_INVALID_CHAR_PATTERN
  end

  def self.char_allowlist_exists?
    SiteSetting.unicode_usernames && SiteSetting.allowed_unicode_username_characters.present?
  end

  def self.allowed_char?(c)
    c.match?(/[\w.-]/) || c.match?(SiteSetting.allowed_unicode_username_characters_regex)
  end
end
