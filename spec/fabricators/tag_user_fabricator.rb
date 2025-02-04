# frozen_string_literal: true

Fabricator(:tag_user) do
  user
  tag
  notification_level { TagUser.notification_levels[:tracking] }
end
