Fabricator(:user_action) do
  user
  action_type UserAction::BOOKMARK
end
