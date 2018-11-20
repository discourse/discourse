require_dependency 'rate_limiter'

class AboutController < ApplicationController

  requires_login only: [:live_post_counts]

  skip_before_action :check_xhr, only: [:index]

  def index
    return redirect_to path('/login') if SiteSetting.login_required? && current_user.nil?

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
