class UsernameCheckerService

  def check_username(username, email)
    if username && username.length > 0
      validator = UsernameValidator.new(username)
      if !validator.valid_format?
        {errors: validator.errors}
      else
        check_username_availability(username, email)
      end
    end
  end

  def check_username_availability(username, email)
    if User.username_available?(username)
      { available: true, is_developer: is_developer?(email) }
    else
      { available: false, suggestion: UserNameSuggester.suggest(username) }
    end
  end

  def is_developer?(value)
    Rails.configuration.respond_to?(:developer_emails) && Rails.configuration.developer_emails.include?(value)
  end

end
