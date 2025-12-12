# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::SET_TOPIC_TIMER) do
  field :type,
        component: :choices,
        extra: {
          content: [
            { id: "auto_close", name: "topic.auto_close.title" },
            { id: "auto_close_after_last_post", name: "topic.auto_close_after_last_post.title" },
            { id: "auto_delete", name: "topic.auto_delete.title" },
            { id: "auto_delete_replies", name: "topic.auto_delete_replies.title" },
            { id: "auto_bump", name: "topic.auto_bump.title" },
          ],
        },
        required: true

  field :duration, component: :relative_time, required: true

  version 1

  triggerables %i[post_created_edited]

  script do |context, fields|
    post = context["post"]
    timer_type = fields.dig("type", "value")

    next if !post.topic
    next unless topic = Topic.find_by(id: post.topic.id)

    duration_minutes = fields.dig("duration", "value")

    case timer_type
    when "auto_close"
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        (Time.now + duration_minutes.minutes).iso8601,
      )
    when "auto_close_after_last_post"
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        nil,
        based_on_last_post: true,
        duration_minutes:,
      )
    when "auto_delete"
      topic.set_or_create_timer(
        TopicTimer.types[:delete],
        (Time.now + duration_minutes.minutes).iso8601,
      )
    when "auto_delete_replies"
      topic.set_or_create_timer(TopicTimer.types[:delete_replies], nil, duration_minutes:)
    when "auto_bump"
      topic.set_or_create_timer(
        TopicTimer.types[:bump],
        (Time.now + duration_minutes.minutes).iso8601,
      )
    end
  end
end
