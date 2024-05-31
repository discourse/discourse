# frozen_string_literal: true

Fabricator(:flag_post_action, from: :post_action) do
  user
  post
  post_action_type_id PostActionType.types[:spam]
end
