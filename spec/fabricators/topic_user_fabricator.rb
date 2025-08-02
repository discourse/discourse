# frozen_string_literal: true

Fabricator(:topic_user) do
  user
  topic
end

Fabricator(:topic_user_tracking, from: :topic_user) do
  notification_level { NotificationLevels.topic_levels[:tracking] }
end

Fabricator(:topic_user_watching, from: :topic_user) do
  notification_level { NotificationLevels.topic_levels[:watching] }
end

Fabricator(:topic_user_regular, from: :topic_user) do
  notification_level { NotificationLevels.topic_levels[:regular] }
end

Fabricator(:topic_user_muted, from: :topic_user) do
  notification_level { NotificationLevels.topic_levels[:muted] }
end
