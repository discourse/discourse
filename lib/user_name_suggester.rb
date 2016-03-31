module UserNameSuggester
  GENERIC_NAMES = ['i', 'me', 'info', 'support', 'admin', 'webmaster', 'hello', 'mail', 'office', 'contact', 'team']

  def self.suggest(name, allow_username = nil)
    return unless name.present?
    name = parse_name_from_email(name)
    find_available_username_based_on(name, allow_username)
  end

  def self.parse_name_from_email(name)
    if name =~ User::EMAIL
      # When 'walter@white.com' take 'walter'
      name = Regexp.last_match[1]
      # When 'me@eviltrout.com' take 'eviltrout'
      name = Regexp.last_match[2] if GENERIC_NAMES.include?(name)
    end
    name
  end

  def self.find_available_username_based_on(name, allow_username = nil)
    name = fix_username(name)
    i = 1
    attempt = name
    until attempt == allow_username || User.username_available?(attempt)
      suffix = i.to_s
      max_length = User.username_length.end - suffix.length - 1
      attempt = "#{name[0..max_length]}#{suffix}"
      i += 1
    end
    attempt
  end

  def self.fix_username(name)
    rightsize_username(sanitize_username(name))
  end

  def self.sanitize_username(name)
    name = ActiveSupport::Inflector.transliterate(name)
    # 1. replace characters that aren't allowed with '_'
    name.gsub!(UsernameValidator::CONFUSING_EXTENSIONS, "_")
    name.gsub!(/[^\w.-]/, "_")
    # 2. removes unallowed leading characters
    name.gsub!(/^\W+/, "")
    # 3. removes unallowed trailing characters
    name = remove_unallowed_trailing_characters(name)
    # 4. unify special characters
    name.gsub!(/[-_.]{2,}/, "_")
    name
  end

  def self.remove_unallowed_trailing_characters(name)
    name.gsub!(/[^A-Za-z0-9]+$/, "")
    name
  end

  def self.rightsize_username(name)
    name = name[0, User.username_length.end]
    name = remove_unallowed_trailing_characters(name)
    name.ljust(User.username_length.begin, '1')
  end

end
