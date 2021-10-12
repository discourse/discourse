# frozen_string_literal: true

class UsernameOverrider
  def self.override(user, new_username)
    if user.username.downcase == new_username.downcase
      user.username = new_username # there may be a change of case
      true
    elsif user.username != UserNameSuggester.fix_username(new_username)
      user.username = UserNameSuggester.suggest(new_username)
      true
    else
      false
    end
  end
end
