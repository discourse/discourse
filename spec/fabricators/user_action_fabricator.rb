# frozen_string_literal: true

Fabricator(:user_action) do
  user
  action_type UserAction::BOOKMARK
end
