# frozen_string_literal: true

class UsernameOverrider
  def self.override(user, new_username)
    if user.username_equals_to?(new_username)
      # override anyway since case could've been changed:
      UsernameChanger.change(user, new_username, user)
      true
    elsif user.username != UserNameSuggester.fix_username(new_username)
      suggested_username = UserNameSuggester.suggest(new_username)
      UsernameChanger.change(user, suggested_username, user)
      true
    else
      false
    end
  end
end
