# frozen_string_literal: true

class ReviewableScore < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :user
  belongs_to :reviewed_by, class_name: "User"
  belongs_to :meta_topic, class_name: "Topic"

  enum :status, { pending: 0, agreed: 1, disagreed: 2, ignored: 3 }

  # To keep things simple the types correspond to `PostActionType` for backwards
  # compatibility, but we can add extra reasons for scores.
  def self.types
    @types ||= PostActionType.flag_types.merge(PostActionType.score_types)
  end

  # When extending post action flags, we need to call this method in order to
  # get the latests flags.
  def self.reload_types
    @types = nil
    types
  end

  def self.add_new_types(type_names)
    next_id = types.values.max + 1

    type_names.each_with_index { |name, idx| @types[name] = next_id + idx }
  end

  def self.score_transitions
    { approved: statuses[:agreed], rejected: statuses[:disagreed], ignored: statuses[:ignored] }
  end

  def score_type
    Reviewable::Collection::Item.new(reviewable_score_type)
  end

  def took_action?
    take_action_bonus > 0
  end

  def self.calculate_score(user, type_bonus, take_action_bonus)
    score = user_flag_score(user) + type_bonus + take_action_bonus
    score > 0 ? score : 0
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
    return 0.0 if user_stat.blank? || user.bot?

    calc_user_accuracy_bonus(user_stat.flags_agreed, user_stat.flags_disagreed)
  end

  def self.calc_user_accuracy_bonus(agreed, disagreed)
    agreed ||= 0
    disagreed ||= 0

    total = (agreed + disagreed).to_f
    return 0.0 if total <= 5
    accuracy_axis = 0.7

    percent_correct = agreed / total
    positive_accuracy = percent_correct >= accuracy_axis

    bottom = positive_accuracy ? accuracy_axis : 0.0
    top = positive_accuracy ? 1.0 : accuracy_axis

    absolute_distance = positive_accuracy ? percent_correct - bottom : top - percent_correct

    axis_distance_multiplier = 1.0 / (top - bottom)
    positivity_multiplier = positive_accuracy ? 1.0 : -1.0

    (
      absolute_distance * axis_distance_multiplier * positivity_multiplier *
        (Math.log(total, 4) * 5.0)
    ).round(2)
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
#  user_accuracy_bonus   :float            default(0.0), not null
#
# Indexes
#
#  index_reviewable_scores_on_reviewable_id  (reviewable_id)
#  index_reviewable_scores_on_user_id        (user_id)
#
