# frozen_string_literal: true

Fabricator(:one_reaction_notification, from: :notification) do
  transient :acting_user
  notification_type Notification.types[:reaction]
  post
  topic { |attrs| attrs[:post].topic }
  data do |attrs|
    acting_user = attrs[:acting_user] || Fabricate(:user)
    {
      topic_title: attrs[:topic].title,
      original_post_id: attrs[:post].id,
      original_post_type: attrs[:post].post_type,
      original_user_id: acting_user.id,
      revision_number: nil,
      display_user_id: acting_user.id,
    }.to_json
  end
end

Fabricator(:multiple_reactions_notification, from: :one_reaction_notification) do
  transient :acting_user_2
  transient :count
  data do |attrs|
    acting_user = attrs[:acting_user] || Fabricate(:user)
    acting_user_2 = attrs[:acting_user_2] || Fabricate(:user)
    {
      topic_title: attrs[:topic].title,
      original_post_id: attrs[:post].id,
      original_post_type: attrs[:post].post_type,
      original_user_id: acting_user_2.id,
      revision_number: nil,
      display_user_id: acting_user_2.id,
      previous_notification_id: 2019,
      user2_id: acting_user.id,
      count: attrs[:count] || 2,
    }.to_json
  end
end
