# frozen_string_literal: true

DiscourseAutomation::Scriptable::CLOSE_TOPIC = "close_topic"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::CLOSE_TOPIC) do
  field :topic, component: :text, required: true, triggerable: :point_in_time
  field :message, component: :text
  field :user, component: :user

  version 1

  triggerables %i[point_in_time stalled_wiki]

  script do |context, fields|
    message = fields.dig("message", "value")
    username = fields.dig("user", "value") || Discourse.system_user.username

    topic_id = fields.dig("topic", "value") || context.dig("topic", "id")
    next unless topic_id
    next unless topic = Topic.find_by(id: topic_id)

    user = User.find_by_username(username)
    next unless user
    next unless Guardian.new(user).can_moderate?(topic)

    topic.update_status("closed", true, user)

    if message.present?
      topic_closed_post = topic.posts.where(action_code: "closed.enabled").last
      topic_closed_post.raw = message

      # FIXME: when there is proper error handling and logging in automation,
      # remove this and allow validations to take place
      topic_closed_post.skip_validation = true

      topic_closed_post.save!
    end
  end
end
