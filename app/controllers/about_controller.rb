require_dependency 'rate_limiter'

class AboutController < ApplicationController
  skip_before_filter :check_xhr, only: [:index]
  before_filter :ensure_logged_in, only: [:live_post_counts]

  def index
    @about = About.new

    respond_to do |format|
      format.html do
        render :index
      end
      format.json do
        render_serialized(@about, AboutSerializer)
      end
    end
  end

  def live_post_counts
    RateLimiter.new(current_user, "live_post_counts", 1, 10.minutes).performed! unless current_user.staff?
    category_topic_ids = Category.pluck(:topic_id).compact!
    public_topics = Topic.listable_topics.visible.secured(Guardian.new(nil)).where.not(id: category_topic_ids)
    stats = { public_topic_count: public_topics.count }
    stats[:public_post_count] = public_topics.sum(:posts_count) - stats[:public_topic_count]
    render json: stats
  end
end
