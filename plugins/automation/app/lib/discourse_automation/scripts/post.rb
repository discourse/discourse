# frozen_string_literal: true

DiscourseAutomation::Scriptable::POST = "post"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::POST) do
  version 1

  placeholder :creator_username

  field :creator, component: :user
  field :topic, component: :text, required: true
  field :post, component: :post, required: true

  triggerables %i[recurring point_in_time]

  script do |context, fields, automation|
    creator_username = fields.dig("creator", "value") || Discourse.system_user.username
    topic_id = fields.dig("topic", "value")
    post_raw = fields.dig("post", "value")

    placeholders = { creator_username: creator_username }.merge(context["placeholders"] || {})

    creator = User.find_by(username: creator_username)
    topic = Topic.find_by(id: topic_id)

    PostCreator.new(creator, topic_id: topic_id, raw: post_raw).create! if creator && topic
  end
end
