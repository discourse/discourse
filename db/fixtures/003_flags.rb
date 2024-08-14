# frozen_string_literal: true

Flag.seed do |s|
  s.id = 6
  s.name = "notify_user"
  s.notify_type = false
  s.auto_action_type = false
  s.require_message = true
  s.applies_to = %w[Post Chat::Message]
  s.skip_reset_flag_callback = true
end
Flag.seed do |s|
  s.id = 3
  s.name = "off_topic"
  s.notify_type = true
  s.auto_action_type = true
  s.require_message = false
  s.applies_to = %w[Post Chat::Message]
  s.skip_reset_flag_callback = true
end
Flag.seed do |s|
  s.id = 4
  s.name = "inappropriate"
  s.notify_type = true
  s.auto_action_type = true
  s.require_message = false
  s.applies_to = %w[Post Topic Chat::Message]
  s.skip_reset_flag_callback = true
end
Flag.seed do |s|
  s.id = 8
  s.name = "spam"
  s.notify_type = true
  s.auto_action_type = true
  s.require_message = false
  s.applies_to = %w[Post Topic Chat::Message]
  s.skip_reset_flag_callback = true
end
Flag.seed do |s|
  s.id = 10
  s.name = "illegal"
  s.notify_type = true
  s.auto_action_type = false
  s.require_message = true
  s.applies_to = %w[Post Topic Chat::Message]
  s.skip_reset_flag_callback = true
end
Flag.seed do |s|
  s.id = 7
  s.name = "notify_moderators"
  s.notify_type = true
  s.auto_action_type = false
  s.require_message = true
  s.applies_to = %w[Post Topic Chat::Message]
  s.skip_reset_flag_callback = true
end
Flag.unscoped.seed do |s|
  s.id = 9
  s.name = "needs_approval"
  s.notify_type = false
  s.auto_action_type = false
  s.require_message = false
  s.score_type = true
  s.applies_to = %w[]
  s.skip_reset_flag_callback = true
end
Flag.unscoped.seed do |s|
  s.id = 2
  s.name = "like"
  s.notify_type = false
  s.auto_action_type = false
  s.require_message = false
  s.score_type = false
  s.applies_to = %w[Post]
  s.skip_reset_flag_callback = true
end
