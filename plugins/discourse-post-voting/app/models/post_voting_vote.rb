# frozen_string_literal: true

class PostVotingVote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :user

  VOTABLE_TYPES = %w[Post PostVotingComment]

  validates :direction, inclusion: { in: %w[up down] }
  validates :votable_type, presence: true, inclusion: { in: VOTABLE_TYPES }
  validates :votable_id, presence: true
  validates :user_id, presence: true
  validate :ensure_valid_vote
  validate :ensure_valid_post, if: -> { votable_type == "Post" }
  validate :ensure_valid_comment, if: -> { votable_type == "PostVotingComment" }

  def self.directions
    @directions ||= { up: "up", down: "down" }
  end

  def self.reverse_direction(direction)
    if direction == directions[:up]
      directions[:down]
    elsif direction == directions[:down]
      directions[:up]
    else
      raise "Invalid direction: #{direction}"
    end
  end

  private

  def ensure_valid_comment
    comment = votable

    if direction != PostVotingVote.directions[:up]
      errors.add(:base, I18n.t("post.post_voting.errors.comment_cannot_be_downvoted"))
    end

    if !comment.post.is_post_voting_topic?
      errors.add(:base, I18n.t("post.post_voting.errors.post_voting_not_enabled"))
    end
  end

  def ensure_valid_post
    post = votable

    if !post.is_post_voting_topic?
      errors.add(:base, I18n.t("post.post_voting.errors.post_voting_not_enabled"))
    elsif post.reply_to_post_number.present?
      errors.add(:base, I18n.t("post.post_voting.errors.voting_not_permitted"))
    end
  end

  def ensure_valid_vote
    if votable.user_id == user_id
      errors.add(:base, I18n.t("post.post_voting.errors.self_voting_not_permitted"))
    end
  end
end

# == Schema Information
#
# Table name: post_voting_votes
#
#  id           :bigint           not null, primary key
#  user_id      :integer          not null
#  created_at   :datetime         not null
#  direction    :string           not null
#  votable_type :string           not null
#  votable_id   :bigint           not null
#
# Indexes
#
#  post_voting_votes_votable_type_and_votable_id_and_user_id_idx  (votable_type,votable_id,user_id) UNIQUE
#  post_voting_votes_votable_type_votable_id_user_id_idx          (votable_type,votable_id,user_id) UNIQUE
#
