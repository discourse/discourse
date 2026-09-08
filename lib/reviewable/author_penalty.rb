# frozen_string_literal: true

class Reviewable < ActiveRecord::Base
  class AuthorPenalty
    include ActiveModel::Serialization

    FOREVER_THRESHOLD = 100.years

    attr_reader :user, :kind, :history, :expires_at

    def self.all_for(user, target_post: nil, reviewable_id: nil)
      return [] if user.blank?

      penalties = []

      if user.silenced?
        penalties << new(
          user: user,
          kind: :silence,
          history: user.silenced_record,
          expires_at: user.silenced_till,
          target_post: target_post,
          reviewable_id: reviewable_id,
        )
      end

      if user.suspended?
        penalties << new(
          user: user,
          kind: :suspension,
          history: user.suspend_record,
          expires_at: user.suspended_till,
          target_post: target_post,
          reviewable_id: reviewable_id,
        )
      end

      penalties
    end

    def initialize(user:, kind:, history:, expires_at:, target_post:, reviewable_id:)
      @user = user
      @kind = kind
      @history = history
      @expires_at = expires_at
      @target_post = target_post
      @reviewable_id = reviewable_id
    end

    def forever
      expires_at.present? && expires_at > FOREVER_THRESHOLD.from_now
    end

    def applied_at
      history&.created_at
    end

    def applied_by
      history&.acting_user
    end

    def automatic
      applied_by.present? && applied_by.bot?
    end

    def reason
      User.format_penalty_reason(history&.details)
    end

    def from_this_target
      return false if history.blank?
      return true if @reviewable_id.present? && history.reviewable_id == @reviewable_id

      @target_post.present? && history.post_id == @target_post.id
    end
  end
end
