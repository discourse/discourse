# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::AUTO_TAG_TOPIC) do
  field :tags, component: :tags, required: true

  version 1

  triggerables %i[post_created_edited pm_created]

  script do |context, fields|
    post = context["post"]

    next if !post.is_first_post?
    next if !post.topic
    next unless topic = Topic.find_by(id: post.topic.id)

    tags = fields.dig("tags", "value")

    DiscourseTagging.tag_topic_by_names(
      topic,
      Guardian.new(Discourse.system_user),
      tags,
      append: true,
    )
  end
end
