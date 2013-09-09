class UsernameCheckerService

  def check_username(username, email)
    validator = UsernameValidator.new(username)
    if !validator.valid_format?
      {errors: validator.errors}
    elsif !SiteSetting.call_discourse_hub?
      check_username_locally(username)
    else
      check_username_with_hub_server(username, email)
    end

  end

  # Contact the Discourse Hub server
  def check_username_with_hub_server(username, email)
    available_locally             = User.username_available?(username)
    info                          = available_globally_and_suggestion_from_hub(username, email)
    available_globally            = info[:available_globally]
    suggestion_from_discourse_hub = info[:suggestion_from_discourse_hub]
    global_match                  = info[:global_match]
    if available_globally && available_locally
      { available: true, global_match: (global_match ? true : false) }
    elsif available_locally && !available_globally
      if email.present?
        # Nickname and email do not match what's registered on the discourse hub.
        { available: false, global_match: false, suggestion: suggestion_from_discourse_hub }
      else
        # The nickname is available locally, but is registered on the discourse hub.
        # We need an email to see if the nickname belongs to this person.
        # Don't give a suggestion until we get the email and try to match it with on the discourse hub.
        { available: false }
      end
    elsif available_globally && !available_locally
      # Already registered on this site with the matching nickname and email address. Why are you signing up again?
      { available: false, suggestion: UserNameSuggester.suggest(username) }
    else
      # Not available anywhere.
      render_unavailable_with_suggestion(suggestion_from_discourse_hub)
    end
  end

  def render_unavailable_with_suggestion(suggestion)
    { available: false, suggestion: suggestion }
  end

  def check_username_locally(username)
    if User.username_available?(username)
      { available: true }
    else
      { available: false, suggestion: UserNameSuggester.suggest(username) }
    end
  end

  def available_globally_and_suggestion_from_hub(username, email)
    if email.present?
      global_match, available, suggestion =
        DiscourseHub.nickname_match?(username, email)
      { available_globally:            available || global_match,
        suggestion_from_discourse_hub: suggestion,
        global_match:                  global_match }
    else
      args = DiscourseHub.nickname_available?(username)
      { available_globally:            args[0],
        suggestion_from_discourse_hub: args[1],
        global_match:                  false }
    end
  end
end
