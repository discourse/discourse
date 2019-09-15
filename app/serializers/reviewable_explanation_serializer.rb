# frozen_string_literal: true

class ReviewableExplanationSerializer < ApplicationSerializer
  attributes(
    :id,
    :total_score,
    :scores,
    :min_score_visibility,
    :hide_post_score
  )

  has_many :scores, serializer: ReviewableScoreExplanationSerializer, embed: :objects

  def id
    object[:reviewable].id
  end

  def hide_post_score
    Reviewable.score_required_to_hide_post
  end

  def spam_silence_score
    Reviewable.spam_score_to_silence_new_user
  end

  def min_score_visibility
    Reviewable.min_score_for_priority
  end

  def total_score
    object[:reviewable].score
  end

  def scores
    object[:scores]
  end
end
