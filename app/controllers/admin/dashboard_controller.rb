# frozen_string_literal: true

class Admin::DashboardController < Admin::AdminController
  def index
    data = AdminDashboardIndexData.fetch_cached_stats

    if SiteSetting.version_checks?
      data.merge!(version_check: DiscourseUpdates.check_version.as_json)
    end

    render json: data
  end

  def moderation; end
  def security; end
  def reports; end

  def general
    render json: AdminDashboardGeneralData.fetch_cached_stats
  end

  def problems
    render_json_dump(problems: AdminDashboardData.fetch_problems(check_force_https: request.ssl?))
  end
end
