# frozen_string_literal: true

WebHookEventType.seed do |b|
  b.id = WebHookEventType::TOPIC
  b.name = "topic"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::POST
  b.name = "post"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::USER
  b.name = "user"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::GROUP
  b.name = "group"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::CATEGORY
  b.name = "category"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::TAG
  b.name = "tag"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::REVIEWABLE
  b.name = "reviewable"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::NOTIFICATION
  b.name = "notification"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::SOLVED
  b.name = "solved"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::ASSIGN
  b.name = "assign"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::USER_BADGE
  b.name = "user_badge"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::GROUP_USER
  b.name = "group_user"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::LIKE
  b.name = "like"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::USER_PROMOTED
  b.name = "user_promoted"
end
