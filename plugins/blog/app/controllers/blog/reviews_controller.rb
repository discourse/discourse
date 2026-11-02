# frozen_string_literal: true

module ::Blog
  class ReviewsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :find_topic

    rescue_from ActiveRecord::RecordInvalid do |error|
      render_json_error error.record, status: :unprocessable_entity
    end

    def index
      records =
        Review
          .where(topic_id: @topic.id)
          .includes(:creator)
          .order(id: :desc)
          .offset(page * 30)
          .limit(31)
          .to_a
      counts = ReviewFeedback.where(review_id: records.map(&:id)).group(:review_id).count
      eligible = Review.eligible_topic?(@topic)
      creators = {}
      reviews =
        records
          .first(30)
          .map do |review|
            allowed =
              creators.fetch(review.creator_id) do
                creators[review.creator_id] = Review.creator_allowed?(review.creator, @topic)
              end
            entry(review, active: eligible && review.current? && allowed).merge(
              feedback_count: counts[review.id] || 0,
            )
          end
      render json: { reviews: reviews, more: records.length > 30 }
    end

    def create
      review = Review.issue!(topic: @topic, user: current_user, label: params[:label].to_s)
      render json: { review: entry(review) }, status: :created
    end

    def destroy
      Review.where(topic_id: @topic.id).find(params[:id]).revoke!(current_user)
      head :no_content
    end

    def topic_feedback
      records =
        ReviewFeedback
          .joins(:review)
          .where(blog_reviews: { topic_id: @topic.id })
          .includes(:review)
          .order(id: :desc)
          .offset(page * 30)
          .limit(31)
          .to_a
      render json: {
               feedback:
                 records
                   .first(30)
                   .map do |record|
                     record.as_json(only: %i[id name email message created_at]).merge(
                       review: record.review.as_json(only: %i[id label post_version revoked_at]),
                     )
                   end,
               more: records.length > 30,
             }
    end

    def feedback
      review = Review.where(topic_id: @topic.id).find(params[:id])
      records = review.feedback.order(:id).offset(page * 30).limit(31).to_a
      render json: {
               feedback: records.first(30).as_json(only: %i[id name email message created_at]),
               more: records.length > 30,
               total: review.feedback.count,
             }
    end

    private

    def find_topic
      raise Discourse::NotFound if Configuration.blog_host?(request)
      @topic = Topic.find(params[:topic_id])
      Configuration.ensure_editor!(current_user, @topic)
      response.headers["Cache-Control"] = "private, no-store"
    end

    def page
      [params[:page].to_i, 0].max
    end

    def entry(review, active: review.accessible?)
      review.as_json(only: %i[id label title post_version created_at expires_at revoked_at]).merge(
        active: active,
        url: (review.url if active),
      )
    end
  end
end
