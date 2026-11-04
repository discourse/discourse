# frozen_string_literal: true

module ::Blog
  class ReviewReaderController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :handle_theme,
                       :check_xhr,
                       :redirect_to_login_if_required,
                       :redirect_to_profile_if_required
    # Reviewers are always anonymous, and without a user core's refresh would
    # delete the signed-in editor's cookie when the reader shares the forum host.
    skip_after_action :perform_refresh_session
    prepend_before_action :prepare_review_request
    before_action :find_review, except: :csrf, unless: :review_page?
    layout "blog_review"

    # NOTE: These rescues override ApplicationController's normal handling;
    # review pages are standalone, so errors are rendered without the Ember app.
    rescue_from Discourse::NotFound, ActiveRecord::RecordNotFound do
      published_url = request.format.json? && Review.published_article_url(params[:review_token])
      if published_url
        render json: { published_url: published_url }, status: :not_found
      else
        render plain: I18n.t("blog.review.unavailable"), status: :not_found
      end
    end

    rescue_from ActiveRecord::RecordInvalid do |error|
      render_json_error error.record, status: :unprocessable_entity
    end

    def csrf
      render json: { csrf: form_authenticity_token }
    end

    def show
      respond_to do |format|
        # The app boots either way, so an expired or revoked link explains itself.
        format.html { render "default/empty", status: review_available? ? :ok : :not_found }
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

    def review_page?
      action_name == "show" && request.format.html?
    end

    def review_available?
      find_review.present?
    rescue Discourse::NotFound
      false
    end
  end
end
