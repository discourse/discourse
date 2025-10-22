# frozen_string_literal: true

module DiscourseSolved::TopicPostersSummaryExtension
  extend ActiveSupport::Concern

  def descriptions_by_id
    if !defined?(@descriptions_by_id)
      super(ids: old_user_ids)

      if id = topic.accepted_answer_user_id
        @descriptions_by_id[id] ||= []
        @descriptions_by_id[id] << I18n.t(:accepted_answer)
      end
    end

    super
  end

  def last_poster_is_topic_creator?
    super || topic.accepted_answer_user_id == topic.last_post_user_id
  end

  def user_ids
    if id = topic.accepted_answer_user_id
      super.insert(1, id)
    else
      super
    end
  end
end
