# frozen_string_literal: true

Fabricator(:group_history) do
  group
  action GroupHistory.actions[:add_user_to_group]
  acting_user { Fabricate(:user) }
  target_user { Fabricate(:user) }
end
