# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::AUTO_TAG_TOPIC) do
  field :tags, component: :tags, required: true
  field :closed_automatically, component: :boolean
  field :closed_manually, component: :boolean

  version 1

  triggerables %i[post_created_edited pm_created topic_closed]

  script do |context, fields|
    topic = nil
    if context["topic"]
      topic = context["topic"]
    else
      post = context["post"]

      next if !post.is_first_post?
      next if !post.topic
      next unless topic = Topic.find_by(id: post.topic.id)
    end

    tags = fields.dig("tags", "value")
    if (context["status"] == :manually && fields.dig("closed_manually", "value")) ||
         (context["status"] == :automatically && fields.dig("closed_automatically", "value")) ||
         context["post"]
      DiscourseTagging.tag_topic_by_names(
        topic,
        Guardian.new(Discourse.system_user),
        tags,
        append: true,
      )
    end
  end
end
