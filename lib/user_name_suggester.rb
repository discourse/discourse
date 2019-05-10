# frozen_string_literal: true

module UserNameSuggester
  GENERIC_NAMES = ['i', 'me', 'info', 'support', 'admin', 'webmaster', 'hello', 'mail', 'office', 'contact', 'team']

  def self.suggest(name_or_email, allowed_username = nil)
    return unless name_or_email.present?

    name = parse_name_from_email(name_or_email)
    find_available_username_based_on(name, allowed_username)
  end

  def self.parse_name_from_email(name_or_email)
    return name_or_email if name_or_email !~ User::EMAIL

    # When 'walter@white.com' take 'walter'
    name = Regexp.last_match[1]

    # When 'me@eviltrout.com' take 'eviltrout'
    name = Regexp.last_match[2] if GENERIC_NAMES.include?(name)
    name
  end

  def self.find_available_username_based_on(name, allowed_username = nil)
    name = fix_username(name)
    i = 1
    attempt = name
    until attempt == allowed_username || User.username_available?(attempt) || i > 100
      suffix = i.to_s
      max_length = User.username_length.end - suffix.length
      attempt = "#{truncate(name, max_length)}#{suffix}"
      i += 1
    end
    until attempt == allowed_username || User.username_available?(attempt) || i > 200
      attempt = SecureRandom.hex[1..SiteSetting.max_username_length]
      i += 1
    end
    attempt
  end

  def self.fix_username(name)
    rightsize_username(sanitize_username(name))
  end

  def self.sanitize_username(name)
    name = name.to_s.dup

    if SiteSetting.unicode_usernames
      name.unicode_normalize!
    else
      name = ActiveSupport::Inflector.transliterate(name)
    end

    name.gsub!(UsernameValidator.invalid_char_pattern, '_')
    name.chars.map! { |c| UsernameValidator.whitelisted_char?(c) ? c : '_' } if UsernameValidator.char_whitelist_exists?
    name.gsub!(UsernameValidator::INVALID_LEADING_CHAR_PATTERN, '')
    name.gsub!(UsernameValidator::CONFUSING_EXTENSIONS, "_")
    name.gsub!(UsernameValidator::INVALID_TRAILING_CHAR_PATTERN, '')
    name.gsub!(UsernameValidator::REPEATED_SPECIAL_CHAR_PATTERN, '_')
    name
  end

  def self.rightsize_username(name)
    name = truncate(name, User.username_length.end)
    name.gsub!(UsernameValidator::INVALID_TRAILING_CHAR_PATTERN, '')

    missing_char_count = User.username_length.begin - name.grapheme_clusters.size
    name << '1' * missing_char_count if missing_char_count > 0
    name
  end

  def self.truncate(name, max_grapheme_clusters)
    clusters = name.grapheme_clusters

    if clusters.size > max_grapheme_clusters
      clusters = clusters[0..max_grapheme_clusters - 1]
      name = clusters.join
    end

    while name.length > UsernameValidator::MAX_CHARS
      clusters.pop
      name = clusters.join
    end

    name
  end
end
