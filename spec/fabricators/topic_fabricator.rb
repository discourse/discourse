# frozen_string_literal: true

Fabricator(:topic) do
  user
  title { sequence(:title) { |i| "This is a test topic #{i}" } }
  category_id do |attrs|
    attrs[:category] ? attrs[:category].id : SiteSetting.uncategorized_category_id
  end

  # Fabrication bypasses PostCreator, for performance reasons, where the counts are updated so we have to handle this manually here.
  after_save do |topic, _transients|
    if !topic.private_message?
      topic.user.user_stat.increment!(:topic_count)
    end
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
