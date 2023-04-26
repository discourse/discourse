# frozen_string_literal: true

Fabricator(:topic) do
  user
  title { sequence(:title) { |i| "This is a test topic #{i}" } }
  category_id do |attrs|
    attrs[:category] ? attrs[:category].id : SiteSetting.uncategorized_category_id
  end
end

Fabricator(:deleted_topic, from: :topic) { deleted_at { 1.minute.ago } }

Fabricator(:closed_topic, from: :topic) { closed true }

Fabricator(:banner_topic, from: :topic) { archetype Archetype.banner }

Fabricator(:private_message_topic, from: :topic) do
  transient :recipient
  category_id { nil }
  title { sequence(:title) { |i| "This is a private message #{i}" } }
  archetype "private_message"
  topic_allowed_users do |t|
    [
      Fabricate.build(:topic_allowed_user, user: t[:user]),
      Fabricate.build(:topic_allowed_user, user: t[:recipient] || Fabricate(:user)),
    ]
  end
end
