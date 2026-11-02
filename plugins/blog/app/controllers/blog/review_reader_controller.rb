# frozen_string_literal: true

module ::Blog
  class ReviewReaderController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :handle_theme,
                       :check_xhr,
                       :redirect_to_login_if_required,
                       :redirect_to_profile_if_required
    prepend_before_action :prepare_review_request
    before_action :find_review, except: :csrf
    layout "blog_review"

    rescue_from Discourse::NotFound, ActiveRecord::RecordNotFound do
      render plain: I18n.t("blog.review.unavailable"), status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |error|
      render_json_error error.record, status: :unprocessable_entity
    end

    def csrf
      render json: { csrf: form_authenticity_token }
    end

    def show
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          render json: @review.as_json(only: %i[title cooked post_version created_at expires_at])
        end
      end
    end

    def feedback
      raise Discourse::InvalidAccess unless request.headers["Origin"] == Configuration.origin
      RateLimiter.new(nil, "blog-review-feedback-ip-#{request.remote_ip}", 30, 1.hour).performed!
      RateLimiter.new(nil, "blog-review-feedback-#{@review.id}", 60, 1.hour).performed!
      @review.submit_feedback!(params.require(:feedback).permit(:name, :email, :message).to_h)
      head :no_content
    end

    private

    def prepare_review_request
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
      response.headers["Referrer-Policy"] = "no-referrer"
      request.env[ApplicationController::NO_THEMES] = true
      request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = nil
      raise Discourse::NotFound unless Configuration.blog_request?(request)
    end

    def find_review
      @review = Review.find_by_token!(params[:review_token])
    end
  end
end
