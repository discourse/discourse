# frozen_string_literal: true

class Reviewable < ActiveRecord::Base
  class PerformResult
    include ActiveModel::Serialization

    attr_reader :reviewable, :status, :created_post, :created_post_topic
    attr_accessor(
      :transition_to,
      :remove_reviewable_ids,
      :errors,
      :recalculate_score,
      :update_flag_stats,
      :after_commit
    )

    def initialize(reviewable, status)
      @status = status
      @reviewable = reviewable
      @remove_reviewable_ids = [reviewable.id] if success?
    end

    def created_post=(created_post)
      @created_post = created_post
      @created_post_topic = created_post.topic
    end

    def success?
      @status == :success
    end
  end
end
