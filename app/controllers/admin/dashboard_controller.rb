# frozen_string_literal: true

class Admin::DashboardController < Admin::StaffController
  def index
    data = AdminDashboardIndexData.fetch_cached_stats

    if SiteSetting.version_checks?
      data.merge!(version_check: DiscourseUpdates.check_version.as_json)
    end

    render json: data
  end

  def moderation
  end
  def security
  end
  def reports
  end

  def general
    render json: AdminDashboardGeneralData.fetch_cached_stats
  end

  def problems
    render_json_dump(problems: AdminDashboardData.fetch_problems(check_force_https: request.ssl?))
  end

  def new_features
    new_features = DiscourseUpdates.new_features

    if current_user.admin? && most_recent = new_features&.first
      DiscourseUpdates.bump_last_viewed_feature_date(current_user.id, most_recent["created_at"])
    end

    data = {
      new_features: new_features,
      has_unseen_features: DiscourseUpdates.has_unseen_features?(current_user.id),
      release_notes_link: AdminDashboardGeneralData.fetch_cached_stats["release_notes_link"],
    }
    render json: data
  end

  def mark_new_features_as_seen
    DiscourseUpdates.mark_new_features_as_seen(current_user.id)
    render json: success_json
  end
end
