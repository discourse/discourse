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
    username_char_whitelisted?
    username_first_char_valid?
    username_last_char_valid?
    username_no_double_special?
    username_does_not_end_with_confusing_suffix?
    errors.empty?
  end

  CONFUSING_EXTENSIONS ||= /\.(js|json|css|htm|html|xml|jpg|jpeg|png|gif|bmp|ico|tif|tiff|woff)$/i
  MAX_CHARS ||= 60

  ASCII_INVALID_CHAR_PATTERN ||= /[^\w.-]/
  UNICODE_INVALID_CHAR_PATTERN ||= /[^\p{Alnum}\p{M}._-]/
  INVALID_LEADING_CHAR_PATTERN ||= /^[^\p{Alnum}\p{M}_]+/
  INVALID_TRAILING_CHAR_PATTERN ||= /[^\p{Alnum}\p{M}]+$/
  REPEATED_SPECIAL_CHAR_PATTERN ||= /[-_.]{2,}/

  private

  def username_present?
    return unless errors.empty?

    if username.blank?
      self.errors << I18n.t(:'user.username.blank')
    end
  end

  def username_length_min?
    return unless errors.empty?

    if username_grapheme_clusters.size < User.username_length.begin
      self.errors << I18n.t(:'user.username.short', min: User.username_length.begin)
    end
  end

  def username_length_max?
    return unless errors.empty?

    if username_grapheme_clusters.size > User.username_length.end
      self.errors << I18n.t(:'user.username.long', max: User.username_length.end)
    elsif username.length > MAX_CHARS
      self.errors << I18n.t(:'user.username.too_long')
    end
  end

  def username_char_valid?
    return unless errors.empty?

    if self.class.invalid_char_pattern.match?(username)
      self.errors << I18n.t(:'user.username.characters')
    end
  end

  def username_char_whitelisted?
    return unless errors.empty? && self.class.char_whitelist_exists?

    if username.chars.any? { |c| !self.class.whitelisted_char?(c) }
      self.errors << I18n.t(:'user.username.characters')
    end
  end

  def username_first_char_valid?
    return unless errors.empty?

    if INVALID_LEADING_CHAR_PATTERN.match?(username_grapheme_clusters.first)
      self.errors << I18n.t(:'user.username.must_begin_with_alphanumeric_or_underscore')
    end
  end

  def username_last_char_valid?
    return unless errors.empty?

    if INVALID_TRAILING_CHAR_PATTERN.match?(username_grapheme_clusters.last)
      self.errors << I18n.t(:'user.username.must_end_with_alphanumeric')
    end
  end

  def username_no_double_special?
    return unless errors.empty?

    if REPEATED_SPECIAL_CHAR_PATTERN.match?(username)
      self.errors << I18n.t(:'user.username.must_not_contain_two_special_chars_in_seq')
    end
  end

  def username_does_not_end_with_confusing_suffix?
    return unless errors.empty?

    if CONFUSING_EXTENSIONS.match?(username)
      self.errors << I18n.t(:'user.username.must_not_end_with_confusing_suffix')
    end
  end

  def username_grapheme_clusters
    @username_grapheme_clusters ||= username.grapheme_clusters
  end

  def self.invalid_char_pattern
    SiteSetting.unicode_usernames ? UNICODE_INVALID_CHAR_PATTERN : ASCII_INVALID_CHAR_PATTERN
  end

  def self.char_whitelist_exists?
    SiteSetting.unicode_usernames && SiteSetting.unicode_username_character_whitelist_regex.present?
  end

  def self.whitelisted_char?(c)
    c.match?(/[\w.-]/) || c.match?(SiteSetting.unicode_username_character_whitelist_regex)
  end
end
