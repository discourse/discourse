# frozen_string_literal: true

module UserNameSuggester
  GENERIC_NAMES = %w[i me info support admin webmaster hello mail office contact team].freeze
  LAST_RESORT_USERNAME = "user"

  def self.suggest(*input, current_username: nil)
    name =
      input.find do |item|
        parsed_name = parse_name_from_email(item)
        break parsed_name if sanitize_username(parsed_name).present?
      end

    name = fix_username(name)
    find_available_username_based_on(name, current_username)
  end

  def self.parse_name_from_email(name_or_email)
    return name_or_email if name_or_email.to_s !~ User::EMAIL

    # When 'walter@white.com' take 'walter'
    name = Regexp.last_match[1]

    # When 'me@eviltrout.com' take 'eviltrout'
    name = Regexp.last_match[2] if GENERIC_NAMES.include?(name)
    name
  end

  def self.find_available_username_based_on(name, current_username = nil)
    offset = nil
    i = 1

    attempt = name
    normalized_attempt = User.normalize_username(attempt)

    original_allowed_username = current_username
    current_username = User.normalize_username(current_username) if current_username

    until (normalized_attempt == current_username || User.username_available?(attempt) || i > 100)
      if offset.nil?
        normalized = User.normalize_username(name)
        similar = "#{normalized}(0|1|2|3|4|5|6|7|8|9)+"

        count = DB.query_single(<<~SQL, like: "#{normalized}%", similar: similar).first
          SELECT count(*)  FROM users
          WHERE username_lower LIKE :like AND
            username_lower SIMILAR TO :similar
        SQL

        if count > 0
          params = {
            count: count + 10,
            name: normalized,
            allowed_normalized: current_username || "",
          }

          # increasing the search space a bit to allow for some extra noise
          available = DB.query_single(<<~SQL, params).first
            WITH numbers AS (SELECT generate_series(1, :count) AS n)

            SELECT n FROM numbers
            LEFT JOIN users ON (
              username_lower = :name || n::varchar
            ) AND (
              username_lower <> :allowed_normalized
            )
            WHERE users.id IS NULL
            ORDER by n ASC
            LIMIT 1
          SQL

          # we start at 1
          offset = available.to_i - 1
          offset = 0 if offset < 0
        else
          offset = 0
        end
      end

      suffix = (i + offset).to_s

      max_length = User.username_length.end - suffix.length
      attempt = "#{truncate(name, max_length)}#{suffix}"
      normalized_attempt = User.normalize_username(attempt)
      i += 1
    end

    until normalized_attempt == current_username || User.username_available?(attempt) || i > 200
      attempt = SecureRandom.hex[1..SiteSetting.max_username_length]
      normalized_attempt = User.normalize_username(attempt)
      i += 1
    end

    if current_username == normalized_attempt
      original_allowed_username
    else
      attempt
    end
  end

  def self.fix_username(name)
    fixed_username = sanitize_username(name)
    if fixed_username.empty?
      fixed_username << sanitize_username(I18n.t("fallback_username"))
      fixed_username << LAST_RESORT_USERNAME if fixed_username.empty?
    end

    rightsize_username(fixed_username)
  end

  def self.sanitize_username(name)
    name = name.to_s.dup

    if SiteSetting.unicode_usernames
      name.unicode_normalize!

      if name.include?("Σ")
        ctx = MiniRacer::Context.new
        name = ctx.eval("#{name.to_s.to_json}.toLowerCase()")
        ctx.dispose
      end
    else
      name = ActiveSupport::Inflector.transliterate(name)
    end

    name.gsub!(UsernameValidator.invalid_char_pattern, "_")
    name = apply_allowlist(name) if UsernameValidator.char_allowlist_exists?
    name.gsub!(UsernameValidator::INVALID_LEADING_CHAR_PATTERN, "")
    name.gsub!(UsernameValidator::CONFUSING_EXTENSIONS, "_")
    name.gsub!(UsernameValidator::INVALID_TRAILING_CHAR_PATTERN, "")
    name.gsub!(UsernameValidator::REPEATED_SPECIAL_CHAR_PATTERN, "_")
    name
  end

  def self.apply_allowlist(name)
    name.grapheme_clusters.map { |c| UsernameValidator.allowed_char?(c) ? c : "_" }.join
  end

  def self.rightsize_username(name)
    name = truncate(name, User.username_length.end)
    name.gsub!(UsernameValidator::INVALID_TRAILING_CHAR_PATTERN, "")

    missing_char_count = User.username_length.begin - name.grapheme_clusters.size
    name << "1" * missing_char_count if missing_char_count > 0
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
