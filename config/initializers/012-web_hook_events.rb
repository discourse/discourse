%i(topic_destroyed topic_recovered).each do |event|
  DiscourseEvent.on(event) do |topic, user|
    WebHook.enqueue_topic_hooks(event, topic, user)
  end
end

DiscourseEvent.on(:topic_status_updated) do |topic, status|
  WebHook.enqueue_topic_hooks("topic_#{status}_status_updated", topic)
end

DiscourseEvent.on(:topic_created) do |topic, _, user|
  WebHook.enqueue_topic_hooks(:topic_created, topic, user)
end

%i(post_created
   post_destroyed
   post_recovered).each do |event|

  DiscourseEvent.on(event) do |post, _, user|
    WebHook.enqueue_post_hooks(event, post, user)
  end
end

DiscourseEvent.on(:post_edited) do |post, topic_changed|
  if post.topic
    WebHook.enqueue_post_hooks(:post_edited, post)

    if post.is_first_post? && topic_changed
      WebHook.enqueue_topic_hooks(:topic_edited, post.topic)
    end
  end
end

%i(
  user_logged_out
  user_created
  user_logged_in
  user_approved
  user_updated
).each do |event|
  DiscourseEvent.on(event) do |user|
    WebHook.enqueue_hooks(:user, user_id: user.id, event_name: event.to_s)
  end
end
