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
  b.id = WebHookEventType::FLAG
  b.name = "flag"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::QUEUED_POST
  b.name = "queued_post"
end
