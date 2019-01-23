Fabricator(:notification) do
  transient :post
  notification_type Notification.types[:mentioned]
  user
  topic { |attrs| attrs[:post]&.topic || Fabricate(:topic, user: attrs[:user]) }
  data '{"poison":"ivy","killer":"croc"}'
end

Fabricator(:quote_notification, from: :notification) do
  notification_type Notification.types[:quoted]
  user
  topic { |attrs| Fabricate(:topic, user: attrs[:user]) }
end

Fabricator(:private_message_notification, from: :notification) do
  notification_type Notification.types[:private_message]
  data do |attrs|
    post = attrs[:post] || Fabricate(:post, topic: attrs[:topic], user: attrs[:user])
    {
      topic_title: attrs[:topic].title,
      original_post_id: post.id,
      original_post_type: post.post_type,
      original_username: post.user.username,
      revision_number: nil,
      display_username: post.user.username
    }.to_json
  end
end

Fabricator(:replied_notification, from: :notification) do
  notification_type Notification.types[:replied]
  data do |attrs|
    post = attrs[:post] || Fabricate(:post, topic: attrs[:topic], user: attrs[:user])
    {
      topic_title: attrs[:topic].title,
      original_post_id: post.id,
      original_username: post.user.username,
      revision_number: nil,
      display_username: post.user.username
    }.to_json
  end
end

Fabricator(:posted_notification, from: :notification) do
  notification_type Notification.types[:posted]
  data do |attrs|
    post = attrs[:post] || Fabricate(:post, topic: attrs[:topic], user: attrs[:user])
    {
      topic_title: attrs[:topic].title,
      original_post_id: post.id,
      original_post_type: post.post_type,
      original_username: post.user.username,
      revision_number: nil,
      display_username: post.user.username
    }.to_json
  end
end
