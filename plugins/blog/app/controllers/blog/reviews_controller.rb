# frozen_string_literal: true

module ::Blog
  class ReviewsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    REVIEWS_PER_PAGE = 30
    FEEDBACK_PER_PAGE = 30

    before_action :ensure_discussion_host
    before_action :prevent_caching
    before_action :find_topic, only: %i[index topic_feedback feedback]

    rescue_from ActiveRecord::RecordInvalid do |error|
      render_json_error error.record, status: :unprocessable_entity
    end

    def index
      records =
        Review
          .where(topic: @topic)
          .includes(:creator)
          .order(id: :desc)
          .offset(page * REVIEWS_PER_PAGE)
          .limit(REVIEWS_PER_PAGE + 1)
          .to_a
      reviews = records.first(REVIEWS_PER_PAGE)
      render json: {
               reviews:
                 serialize_data(
                   reviews,
                   ReviewSerializer,
                   active_review_ids: Review.accessible_ids(reviews, @topic),
                   feedback_counts: ReviewFeedback.where(review: reviews).group(:review_id).count,
                 ),
               more: records.length > REVIEWS_PER_PAGE,
             }
    end

    def create
      Review::Create.call(service_params) do
        on_success do |review:, topic:|
          render json: {
                   review:
                     ReviewSerializer.new(
                       review,
                       root: false,
                       active_review_ids: Review.accessible_ids([review], topic),
                     ).as_json,
                 },
                 status: :created
        end
        on_failed_contract { raise Discourse::NotFound }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_blog_topic) { raise Discourse::InvalidAccess }
        on_failed_policy(:blog_is_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failed_policy(:topic_is_reviewable) { raise Discourse::InvalidAccess }
        on_failed_policy(:within_review_limit) do
          raise Discourse::InvalidParameters.new(I18n.t("blog.review.limit"))
        end
        on_model_not_found(:snapshot) { raise Discourse::InvalidParameters.new(:cooked) }
        on_failed_policy(:snapshot_within_size_limit) do
          raise Discourse::InvalidParameters.new(:cooked)
        end
        on_model_errors(:review) do |review|
          render_json_error review, status: :unprocessable_entity
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def destroy
      Review::Revoke.call(service_params.deep_merge(params: { review_id: params[:id] })) do
        on_success { head :no_content }
        on_failed_contract { raise Discourse::NotFound }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_blog_topic) { raise Discourse::InvalidAccess }
        on_model_not_found(:review) { raise Discourse::NotFound }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def topic_feedback
      scope = ReviewFeedback.joins(:review).where(blog_reviews: { topic_id: @topic.id })
      records =
        scope
          .includes(:review)
          .order(id: :desc)
          .offset(page * FEEDBACK_PER_PAGE)
          .limit(FEEDBACK_PER_PAGE + 1)
          .to_a
      render json: {
               feedback:
                 serialize_data(
                   records.first(FEEDBACK_PER_PAGE),
                   ReviewFeedbackSerializer,
                   include_review: true,
                 ),
               more: records.length > FEEDBACK_PER_PAGE,
               # Feedback is paginated, so one page can't tell the client which version is newest.
               latest_version: scope.maximum("blog_reviews.post_version"),
             }
    end

    def feedback
      review = Review.where(topic: @topic).find(params[:id])
      records =
        review
          .feedback
          .order(:id)
          .offset(page * FEEDBACK_PER_PAGE)
          .limit(FEEDBACK_PER_PAGE + 1)
          .to_a
      render json: {
               feedback: serialize_data(records.first(FEEDBACK_PER_PAGE), ReviewFeedbackSerializer),
               more: records.length > FEEDBACK_PER_PAGE,
               total: review.feedback.count,
             }
    end

    private

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end

    def prevent_caching
      response.headers["Cache-Control"] = "private, no-store"
    end

    def find_topic
      @topic = Topic.find(params[:topic_id])
      guardian.ensure_can_edit_blog_topic!(@topic)
    end

    def page
      [params[:page].to_i, 0].max
    end
  end
end
