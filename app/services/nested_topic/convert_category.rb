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
  step :enable_nested_view_for_existing_topics
  step :mark_conversion_completed
  only_if(:converted_topics?) { step :enqueue_nested_reply_stats_backfill }

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

    loop do
      converted_batch_count = convert_topic_batch(category.id)
      break if converted_batch_count.zero?

      converted_topic_count += converted_batch_count
    end

    context[:converted_topic_count] = converted_topic_count
  end

  def convert_topic_batch(category_id)
    DB
      .query_single(<<~SQL, category_id:, archetype: Archetype.default, batch_size: BATCH_SIZE)
      WITH topics_to_convert AS (
        SELECT t.id
        FROM topics t
        WHERE t.category_id = :category_id
          AND t.archetype = :archetype
          AND t.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM nested_topics nt
            WHERE nt.topic_id = t.id
          )
        ORDER BY t.id
        LIMIT :batch_size
      ), inserted AS (
        INSERT INTO nested_topics (topic_id, created_at, updated_at)
        SELECT id, NOW(), NOW()
        FROM topics_to_convert
        ON CONFLICT (topic_id) DO NOTHING
        RETURNING 1
      )
      SELECT COUNT(*)
      FROM inserted
    SQL
      .first
      .to_i
  end

  def mark_conversion_completed(category:)
    category.mark_nested_replies_conversion_completed!
  end

  def converted_topics?(converted_topic_count:)
    converted_topic_count.positive?
  end

  def enqueue_nested_reply_stats_backfill(category:)
    Jobs.enqueue(:backfill_nested_reply_stats, category_id: category.id)
  end
end
