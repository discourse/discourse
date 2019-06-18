# frozen_string_literal: true

class UsernameCheckerService
  def initialize(allow_reserved_username: false)
    @allow_reserved_username = allow_reserved_username
  end

  def check_username(username, email)
    if username && username.length > 0
      validator = UsernameValidator.new(username)
      if !validator.valid_format?
        { errors: validator.errors }
      else
        check_username_availability(username, email)
      end
    end
  end

  def check_username_availability(username, email)
    available = User.username_available?(
      username,
      email,
      allow_reserved_username: @allow_reserved_username
    )

    if available
      { available: true, is_developer: is_developer?(email) }
    else
      { available: false, suggestion: UserNameSuggester.suggest(username) }
    end
  end

  def is_developer?(value)
    Rails.configuration.respond_to?(:developer_emails) && Rails.configuration.developer_emails.include?(value)
  end

  def self.is_developer?(email)
    UsernameCheckerService.new.is_developer?(email)
  end

end
