# frozen_string_literal: true

class ReviewableScore < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :user
  belongs_to :reviewed_by, class_name: 'User'
  belongs_to :meta_topic, class_name: 'Topic'

  # To keep things simple the types correspond to `PostActionType` for backwards
  # compatibility, but we can add extra reasons for scores.
  def self.types
    @types ||= PostActionType.flag_types.merge(
      needs_approval: 9
    )
  end

  def self.statuses
    @statuses ||= Enum.new(
      pending: 0,
      agreed: 1,
      disagreed: 2,
      ignored: 3
    )
  end

  def self.score_transitions
    {
      approved: statuses[:agreed],
      rejected: statuses[:disagreed],
      ignored: statuses[:ignored]
    }
  end

  # Generate `pending?`, `rejected?`, etc helper methods
  statuses.each do |name, id|
    define_method("#{name}?") { status == id }
    self.class.define_method(name) { where(status: id) }
  end

  def score_type
    Reviewable::Collection::Item.new(reviewable_score_type)
  end

  def took_action?
    take_action_bonus > 0
  end

  # A user's flag score is:
  #   1.0 + trust_level + user_accuracy_bonus
  #   (trust_level is 5 for staff)
  def self.user_flag_score(user)
    1.0 + (user.staff? ? 5.0 : user.trust_level.to_f) + user_accuracy_bonus(user)
  end

  # A user's accuracy bonus is:
  #   if 5 or less flags => 0.0
  #   if > 5 flags => (agreed flags / total flags) * 5.0
  def self.user_accuracy_bonus(user)
    user_stat = user&.user_stat
    return 0.0 if user_stat.blank?

    calc_user_accuracy_bonus(
      user_stat.flags_agreed,
      user_stat.flags_disagreed,
      user_stat.flags_ignored
    )
  end

  def self.calc_user_accuracy_bonus(agreed, disagreed, ignored)
    agreed ||= 0
    disagreed ||= 0
    ignored ||= 0

    total = (agreed + disagreed + ignored).to_f
    return 0.0 if total <= 5

    (agreed / total) * 5.0
  end

  def reviewable_conversation
    return if meta_topic.blank?
    Reviewable::Conversation.new(meta_topic)
  end

end

# == Schema Information
#
# Table name: reviewable_scores
#
#  id                    :bigint           not null, primary key
#  reviewable_id         :integer          not null
#  user_id               :integer          not null
#  reviewable_score_type :integer          not null
#  status                :integer          not null
#  score                 :float            default(0.0), not null
#  take_action_bonus     :float            default(0.0), not null
#  reviewed_by_id        :integer
#  reviewed_at           :datetime
#  meta_topic_id         :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  reason                :string
#
# Indexes
#
#  index_reviewable_scores_on_reviewable_id  (reviewable_id)
#  index_reviewable_scores_on_user_id        (user_id)
#
