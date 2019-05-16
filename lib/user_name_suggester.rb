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
    offset = nil
    i = 1
    attempt = name

    until attempt == allowed_username || User.username_available?(attempt) || i > 100

      if offset.nil?
        normalized = User.normalize_username(name)
        similar = "#{normalized}(0|1|2|3|4|5|6|7|8|9)+"

        count = DB.query_single(<<~SQL, like: "#{normalized}%", similar: similar).first
          SELECT count(*)  FROM users
          WHERE username_lower LIKE :like AND
            username_lower SIMILAR TO :similar
        SQL

        if count > 0
          available = DB.query_single(<<~SQL, count: count, name: normalized).first
            WITH numbers AS (SELECT generate_series(1, :count) AS n)

            SELECT n FROM numbers
            LEFT JOIN users ON username_lower = :name || n::varchar
            WHERE users.id IS NULL
            ORDER by n ASC
            LIMIT 1
          SQL

          # we start at 1
          offset = available - 1
        else
          offset = 0
        end
      end

      suffix = (i + offset).to_s
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
