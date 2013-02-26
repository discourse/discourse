Fabricator(:topic) do
  user
  title { sequence(:title) { |i| "Test topic #{i}" } }
end

Fabricator(:deleted_topic, from: :topic) do
  deleted_at Time.now
end

Fabricator(:topic_allowed_user) do
end

Fabricator(:private_message_topic, from: :topic) do
  user
  title { sequence(:title) { |i| "Private Message #{i}" } }
  archetype "private_message"
  topic_allowed_users{|t| [
    Fabricate.build(:topic_allowed_user, user_id: t[:user].id),
    Fabricate.build(:topic_allowed_user, user_id: Fabricate(:coding_horror).id)
  ]}
end
