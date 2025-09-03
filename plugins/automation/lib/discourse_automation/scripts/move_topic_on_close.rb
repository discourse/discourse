# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::MOVE_TOPIC_ON_CLOSE) do
  field :source_category, component: :category, required: true
  field :target_category, component: :category, required: true

  version 1

  triggerables %i[topic_closed]

  script do |context, fields|
    topic = context["topic"]

    Rails.logger.info("Automation triggered! Context: #{context.inspect}")


    source_category_id = fields.dig("source_category", "value")
    target_category_id = fields.dig("target_category", "value")

    next unless topic.category_id == source_category_id

    topic.category_id = target_category_id
    topic.save!

    Rails.logger.info("Moved topic #{topic.id} from category #{source_category_id} to #{target_category_id}")

    # next if !post.is_first_post?
    # next if !post.topic
    # next unless topic = Topic.find_by(id: post.topic.id)

    # tags = fields.dig("tags", "value")

    # DiscourseTagging.tag_topic_by_names(
    #   topic,
    #   Guardian.new(Discourse.system_user),
    #   tags,
    #   append: true,
    # )
  end
end
