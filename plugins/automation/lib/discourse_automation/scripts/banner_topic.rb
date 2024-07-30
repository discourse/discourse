# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::BANNER_TOPIC) do
  field :topic_id, component: :text, required: true
  field :banner_until, component: :date_time
  field :user, component: :user

  version 1

  triggerables [:point_in_time]

  script do |_, fields|
    next unless topic_id = fields.dig("topic_id", "value")
    next unless topic = Topic.find_by(id: topic_id)

    banner_until = fields.dig("banner_until", "value") || nil

    username = fields.dig("user", "value") || Discourse.system_user.username
    next unless user = User.find_by(username: username)

    topic.make_banner!(user, banner_until)
  end
end
