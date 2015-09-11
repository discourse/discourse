module UserNameSuggester

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
      name = Regexp.last_match[2] if ['i', 'me'].include?(name)
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
    name = name.gsub(/^[^[:alnum:]]+|\W+$/, "")
               .gsub(/\W+/, "_")
               .gsub(/^\_+/, '')
               .gsub(/[\-_\.]{2,}/, "_")
    name
  end

  def self.rightsize_username(name)
    name.ljust(User.username_length.begin, '1')[0, User.username_length.end]
  end

end
