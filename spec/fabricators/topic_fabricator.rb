Fabricator(:topic) do
  user
  title { sequence(:title) { |i| "This is a test topic #{i}" } }
  category_id { SiteSetting.uncategorized_category_id }
end

Fabricator(:deleted_topic, from: :topic) do
  deleted_at Time.now
end

Fabricator(:closed_topic, from: :topic) do
  closed true
end

Fabricator(:banner_topic, from: :topic) do
  archetype Archetype.banner
end

Fabricator(:private_message_topic, from: :topic) do
  category_id { nil }
  title { sequence(:title) { |i| "This is a private message #{i}" } }
  archetype "private_message"
  topic_allowed_users { |t| [
    Fabricate.build(:topic_allowed_user, user: t[:user]),
    Fabricate.build(:topic_allowed_user, user: Fabricate(:coding_horror))
  ]}
end
