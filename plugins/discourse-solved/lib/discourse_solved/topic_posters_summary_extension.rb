# frozen_string_literal: true

module DiscourseSolved::TopicPostersSummaryExtension
  extend ActiveSupport::Concern

  def descriptions_by_id
    if !defined?(@descriptions_by_id)
      super(ids: old_user_ids)

      Array(topic.accepted_answer_user_ids).each do |id|
        @descriptions_by_id[id] ||= []
        @descriptions_by_id[id] << I18n.t(:accepted_answer)
      end
    end

    super
  end

  def last_poster_is_topic_creator?
    super || Array(topic.accepted_answer_user_ids).include?(topic.last_post_user_id)
  end

  def user_ids
    ids = Array(topic.accepted_answer_user_ids)
    ids.any? ? super.insert(1, *ids) : super
  end
end
