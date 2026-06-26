# frozen_string_literal: true

class NestedTopic::ConvertCategory
  include Service::Base

  BATCH_SIZE = 1000

  params do
    attribute :category_id, :integer

    validates :category_id, presence: true
  end

  model :category
  policy :nested_replies_enabled
  policy :can_edit_category
  policy :category_nested_replies_enabled

  transaction do
    step :enable_nested_view_for_existing_topics
    step :mark_conversion_completed
  end

  private

  def fetch_category(params:)
    Category.find_by(id: params.category_id)
  end

  def nested_replies_enabled
    SiteSetting.nested_replies_enabled
  end

  def can_edit_category(guardian:, category:)
    guardian.can_edit?(category)
  end

  def category_nested_replies_enabled(category:)
    category.nested_replies_default
  end

  def enable_nested_view_for_existing_topics(category:)
    converted_topic_count = 0

    category
      .topics
      .where(archetype: Archetype.default, deleted_at: nil)
      .where.not(id: NestedTopic.select(:topic_id))
      .in_batches(of: BATCH_SIZE) do |topics|
        topic_ids = topics.pluck(:id)
        next if topic_ids.empty?

        timestamp = Time.zone.now
        NestedTopic.insert_all(
          topic_ids.map do |topic_id|
            { topic_id: topic_id, created_at: timestamp, updated_at: timestamp }
          end,
          unique_by: :index_nested_topics_on_topic_id,
        )
        converted_topic_count += topic_ids.size
      end

    context[:converted_topic_count] = converted_topic_count
  end

  def mark_conversion_completed(category:)
    category.mark_nested_replies_conversion_completed!
  end
end
