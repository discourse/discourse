# frozen_string_literal: true

%i(
  topic_recovered
).each do |event|
  DiscourseEvent.on(event) do |topic, _|
    WebHook.enqueue_topic_hooks(event, topic)
  end
end

DiscourseEvent.on(:topic_status_updated) do |topic, status|
  WebHook.enqueue_topic_hooks("topic_#{status}_status_updated", topic)
end

DiscourseEvent.on(:topic_created) do |topic, _, _|
  WebHook.enqueue_topic_hooks(:topic_created, topic)
end

%i(
  post_created
  post_recovered
).each do |event|
  DiscourseEvent.on(event) do |post, _, _|
    WebHook.enqueue_post_hooks(event, post)
  end
end

DiscourseEvent.on(:post_edited) do |post, topic_changed|
  unless post.topic&.trashed?

    # if we are editing the OP and the topic is changed, do not send
    # the post_edited event -- this event is sent separately because
    # when we update the OP in the UI we send two API calls in this order:
    #
    # PUT /t/topic-name
    # PUT /post/243552
    if post.is_first_post? && topic_changed
      WebHook.enqueue_topic_hooks(:topic_edited, post.topic)
    else
      WebHook.enqueue_post_hooks(:post_edited, post)
    end
  end
end

%i(
  user_logged_out
  user_created
  user_logged_in
  user_approved
  user_updated
  user_confirmed_email
).each do |event|
  DiscourseEvent.on(event) do |user|
    WebHook.enqueue_object_hooks(:user, user, event)
  end
end

%i(
  group_created
  group_updated
).each do |event|
  DiscourseEvent.on(event) do |group|
    WebHook.enqueue_object_hooks(:group, group, event)
  end
end

%i(
  category_created
  category_updated
).each do |event|
  DiscourseEvent.on(event) do |category|
    WebHook.enqueue_object_hooks(:category, category, event)
  end
end

%i(
  tag_created
  tag_updated
).each do |event|
  DiscourseEvent.on(event) do |tag|
    WebHook.enqueue_object_hooks(:tag, tag, event, TagSerializer)
  end
end

%i(
  user_badge_granted
).each do |event|
  # user_badge_revoked
  DiscourseEvent.on(event) do |badge, user_id|
    ub = UserBadge.find_by(badge: badge, user_id: user_id)
    WebHook.enqueue_object_hooks(:user_badge, ub, event, UserBadgeSerializer)
  end
end

%i(
  reviewable_created
  reviewable_score_updated
).each do |event|
  DiscourseEvent.on(event) do |reviewable|
    WebHook.enqueue_object_hooks(:reviewable, reviewable, event, reviewable.serializer)
  end
end

DiscourseEvent.on(:reviewable_transitioned_to) do |status, reviewable|
  WebHook.enqueue_object_hooks(:reviewable, reviewable, :reviewable_transitioned_to, reviewable.serializer)
end

DiscourseEvent.on(:notification_created) do |notification|
  WebHook.enqueue_object_hooks(:notification, notification, :notification_created, NotificationSerializer)
end

DiscourseEvent.on(:user_added_to_group) do |user, group, options|
  group_user = GroupUser.find_by(user: user, group: group)
  WebHook.enqueue_object_hooks(:group_user, group_user, :user_added_to_group, WebHookGroupUserSerializer)
end

DiscourseEvent.on(:like_created) do |post_action|
  user = post_action.user
  group_ids = user.groups.map(&:id)
  topic = Topic.includes(:tags).joins(:posts).find_by(posts: { id: post_action.post_id })
  category_id = topic&.category_id
  tag_ids = topic&.tag_ids

  WebHook.enqueue_object_hooks(:like,
    post_action, :post_liked, WebHookLikeSerializer,
    group_ids: group_ids, category_id: category_id, tag_ids: tag_ids
  )
end
