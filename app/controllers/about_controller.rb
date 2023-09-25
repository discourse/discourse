# frozen_string_literal: true

class AboutController < ApplicationController
  requires_login only: [:live_post_counts]

  skip_before_action :check_xhr, only: [:index]

  def index
    return redirect_to path("/login") if SiteSetting.login_required? && current_user.nil?

    @about = About.new(current_user)
    @title = "#{I18n.t("js.about.simple_title")} - #{SiteSetting.title}"
    respond_to do |format|
      format.html { render :index }
      format.json { render_json_dump(AboutSerializer.new(@about, scope: guardian)) }
    end
  end

  def live_post_counts
    unless current_user.staff?
      RateLimiter.new(current_user, "live_post_counts", 1, 10.minutes).performed!
    end
    category_topic_ids = Category.select(:topic_id).where.not(topic_id: nil)
    public_topics =
      Topic.listable_topics.visible.secured(Guardian.new(nil)).where.not(id: category_topic_ids)
    stats = { public_topic_count: public_topics.count }
    stats[:public_post_count] = public_topics.sum(:posts_count) - stats[:public_topic_count]
    render json: stats
  end
end
