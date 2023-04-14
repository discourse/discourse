# frozen_string_literal: true

Fabricator(:post_action) do
  post
  user
  post_action_type_id PostActionType.types[:like]
end
