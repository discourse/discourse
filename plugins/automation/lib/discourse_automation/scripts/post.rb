# frozen_string_literal: true

DiscourseAutomation::Scriptable::POST = "post"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::POST) do
  version 1

  placeholder :creator_username

  field :creator, component: :user
  field :topic, component: :text, required: true
  field :post, component: :post, required: true

  triggerables %i[recurring point_in_time user_updated]

  script do |context, fields, automation|
    creator_username = fields.dig("creator", "value") || Discourse.system_user.username
    topic_id = fields.dig("topic", "value")
    post_raw = fields.dig("post", "value")

    placeholders = { creator_username: creator_username }.merge(context["placeholders"] || {})
    creator = User.find_by(username: creator_username)
    topic = Topic.find_by(id: topic_id)

    if context["kind"] == DiscourseAutomation::Triggerable::USER_UPDATED
      user_data = context["user_data"]
      user_profile_data = user_data[:profile_data]
      user_custom_fields =
        user_data[:custom_fields].each_with_object({}) do |(k, v), hash|
          hash[k.gsub(/\s+/, "_").underscore] = v
        end
      user = User.find(context["user"].id)
      placeholders = placeholders.merge(user_profile_data, user_custom_fields)

      post_raw = utils.apply_placeholders(post_raw, placeholders)
    end

    new_post = PostCreator.new(creator, topic_id: topic_id, raw: post_raw).create! if creator &&
      topic
    if context["kind"] == DiscourseAutomation::Triggerable::USER_UPDATED && new_post.persisted?
      user.user_custom_fields.create(
        name: automation.trigger_field("automation_name")["value"],
        value: "true",
      )
    end
  end
end
