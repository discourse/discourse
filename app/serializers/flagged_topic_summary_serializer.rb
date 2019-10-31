# frozen_string_literal: true

class FlaggedTopicSummarySerializer < ActiveModel::Serializer

  attributes(
    :id,
    :flag_counts,
    :user_ids,
    :last_flag_at
  )

  has_one :topic, serializer: FlaggedTopicSerializer

  def id
    topic.id
  end

  def flag_counts
    object.flag_counts.map do |k, v|
      { post_action_type_id: k, count: v, name_key: PostActionType.types[k] }
    end
  end

  def user_ids
    object.user_ids
  end

  def last_flag_at
    object.last_flag_at
  end
end
