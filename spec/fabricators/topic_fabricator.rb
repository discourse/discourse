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

Fabricator(:group_private_message_topic, from: :topic) do
  transient :recipient_group
  category_id { nil }
  title { sequence(:title) { |i| "This is a private message #{i} to a group" } }
  archetype "private_message"
  topic_allowed_users { |t| [Fabricate.build(:topic_allowed_user, user: t[:user])] }
  topic_allowed_groups { |t| [Fabricate.build(:topic_allowed_group, group: t[:recipient_group])] }
end

Fabricator(:new_reply_topic, from: :topic) do
  before_validation { raise "new_reply_topic fabricator requires the `user` param" if !user }

  after_create do |topic|
    Fabricate.times(2, :post, topic: topic)
    TopicUser.change(
      user.id,
      topic.id,
      notification_level: TopicUser.notification_levels[:tracking],
    )
    TopicUser.update_last_read(user, topic.id, 1, 1, 1)
  end
end
