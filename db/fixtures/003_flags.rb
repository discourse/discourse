# frozen_string_literal: true

Flag.seed do |s|
  s.id = 6
  s.name = "notify_user"
  s.notify_type = false
  s.auto_action_type = false
  s.custom_type = true
  s.applies_to = %w[Post Chat::Message]
end
Flag.seed do |s|
  s.id = 3
  s.name = "off_topic"
  s.notify_type = true
  s.auto_action_type = true
  s.custom_type = false
  s.applies_to = %w[Post Chat::Message]
end
Flag.seed do |s|
  s.id = 4
  s.name = "inappropriate"
  s.notify_type = true
  s.auto_action_type = true
  s.custom_type = false
  s.applies_to = %w[Post Topic Chat::Message]
end
Flag.seed do |s|
  s.id = 8
  s.name = "spam"
  s.notify_type = true
  s.auto_action_type = true
  s.custom_type = false
  s.applies_to = %w[Post Topic Chat::Message]
end
Flag.seed do |s|
  s.id = 10
  s.name = "illegal"
  s.notify_type = true
  s.auto_action_type = false
  s.custom_type = true
  s.applies_to = %w[Post Topic Chat::Message]
end
Flag.seed do |s|
  s.id = 7
  s.name = "notify_moderators"
  s.notify_type = true
  s.auto_action_type = false
  s.custom_type = true
  s.applies_to = %w[Post Topic Chat::Message]
end
Flag.unscoped.seed do |s|
  s.id = 9
  s.name = "needs_approval"
  s.notify_type = false
  s.auto_action_type = false
  s.custom_type = false
  s.score_type = true
  s.applies_to = %w[]
end
