require_dependency 'rate_limiter'

class AboutController < ApplicationController
  requires_login only: %i[live_post_counts]

  skip_before_action :check_xhr, only: %i[index]

  def index
    if SiteSetting.login_required? && current_user.nil?
      return redirect_to path('/login')
    end

    @about = About.new
    @title = "#{I18n.t('js.about.simple_title')} - #{SiteSetting.title}"
    respond_to do |format|
      format.html { render :index }
      format.json { render_serialized(@about, AboutSerializer) }
    end
  end

  def live_post_counts
    unless current_user.staff?
      RateLimiter.new(current_user, 'live_post_counts', 1, 10.minutes)
        .performed!
    end
    category_topic_ids = Category.pluck(:topic_id).compact!
    public_topics =
      Topic.listable_topics.visible.secured(Guardian.new(nil)).where.not(
        id: category_topic_ids
      )
    stats = { public_topic_count: public_topics.count }
    stats[:public_post_count] =
      public_topics.sum(:posts_count) - stats[:public_topic_count]
    render json: stats
  end
end
