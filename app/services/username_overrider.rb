# frozen_string_literal: true

class UsernameOverrider
  def self.override(user, new_username)
    if user.username_equal_to?(new_username)
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
