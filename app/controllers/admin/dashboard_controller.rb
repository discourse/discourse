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
    ProblemCheck.realtime.run_all

    render json: { problems: serialize_data(AdminNotice.problem.all, AdminNoticeSerializer) }
  end

  def new_features
    force_refresh = params[:force_refresh] == "true"

    if force_refresh
      RateLimiter.new(
        current_user,
        "force-refresh-new-features",
        5,
        1.minute,
        apply_limit_to_staff: true,
      ).performed!
    end

    new_features = DiscourseUpdates.new_features(force_refresh:)

    if current_user.admin? && most_recent = new_features&.first
      DiscourseUpdates.bump_last_viewed_feature_date(current_user.id, most_recent["created_at"])
    end

    data = {
      new_features: new_features,
      has_unseen_features: DiscourseUpdates.has_unseen_features?(current_user.id),
      release_notes_link: AdminDashboardGeneralData.fetch_cached_stats["release_notes_link"],
    }

    mark_new_features_as_seen

    render json: data
  end

  def toggle_feature
    Experiments::Toggle.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:setting_is_available) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  private

  def mark_new_features_as_seen
    DiscourseUpdates.mark_new_features_as_seen(current_user.id)
  end
end
