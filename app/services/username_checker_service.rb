class UsernameCheckerService

  def check_username(username, email)
    if username && username.length > 0
      validator = UsernameValidator.new(username)
      if !validator.valid_format?
        {errors: validator.errors}
      else
        check_username_availability(username)
      end
    end
  end

  def check_username_availability(username)
    if User.username_available?(username)
      { available: true }
    else
      { available: false, suggestion: UserNameSuggester.suggest(username) }
    end
  end

end
