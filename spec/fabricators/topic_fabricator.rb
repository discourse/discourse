Fabricator(:topic) do
  user
  title { sequence(:title) { |i| "This is a test topic #{i}" } }
  category_id { SiteSetting.uncategorized_category_id }
end

Fabricator(:deleted_topic, from: :topic) do
  deleted_at Time.now
end

Fabricator(:topic_allowed_user) do
end

Fabricator(:banner_topic, from: :topic) do
  archetype Archetype.banner
end

Fabricator(:private_message_topic, from: :topic) do
  user
  category_id { nil }
  title { sequence(:title) { |i| "This is a private message #{i}" } }
  archetype "private_message"
  topic_allowed_users{|t| [
    Fabricate.build(:topic_allowed_user, user_id: t[:user].id),
    Fabricate.build(:topic_allowed_user, user_id: Fabricate(:coding_horror).id)
  ]}
end
