# frozen_string_literal: true

Fabricator(:topic) do
  user
  title { sequence(:title) { |i| "This is a test topic #{i}" } }
  category_id do |attrs|
    attrs[:category] ? attrs[:category].id : SiteSetting.uncategorized_category_id
  end
end

Fabricator(:deleted_topic, from: :topic) do
  deleted_at { 1.minute.ago }
end

Fabricator(:closed_topic, from: :topic) do
  closed true
end

Fabricator(:banner_topic, from: :topic) do
  archetype Archetype.banner
end

Fabricator(:with_posts_topic, from: :topic) do
  after_create do |topic|
    3.times do
      Fabricate(:post, topic: topic)
    end
  end
end

Fabricator(:private_message_topic, from: :topic) do
  transient :recipient
  category_id { nil }
  title { sequence(:title) { |i| "This is a private message #{i}" } }
  archetype "private_message"
  topic_allowed_users { |t| [
    Fabricate.build(:topic_allowed_user, user: t[:user]),
    Fabricate.build(:topic_allowed_user, user: t[:recipient] || Fabricate(:user))
  ]}
end
