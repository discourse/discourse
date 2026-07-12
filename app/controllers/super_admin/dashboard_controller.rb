# frozen_string_literal: true

class SuperAdmin::DashboardController < SuperAdmin::StaffController
  BULK_REPORTS_FILTER_KEYS = %i[start_date end_date].freeze

  before_action :ensure_admin,
                only: %i[available_reports update_reports_section update_configuration]

  def index
    if dashboard_improvements?
      data = dashboard_sections_payload
    else
      data = AdminDashboardIndexData.fetch_cached_stats

      if SiteSetting.version_checks?
        data.merge!(version_check: DiscourseUpdates.check_version.as_json)
      end
    end

    render json: data
  end

  def update_configuration
    sections = params.permit(sections: %i[id visible])[:sections] || []
    AdminDashboardSectionConfiguration.update(sections, actor: current_user)
    head :no_content
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

    render json: { problems: serialized_problems }
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
    new_features_with_permanent_uc =
      DiscourseUpdates.merge_new_features_with_upcoming_changes(
        new_features&.map { |item| item.symbolize_keys } || [],
      )

    if current_user.admin? && most_recent = new_features_with_permanent_uc&.first
      DiscourseUpdates.bump_last_viewed_feature_date(current_user.id, most_recent[:created_at])
    end

    data = {
      new_features: new_features_with_permanent_uc,
      has_unseen_features: DiscourseUpdates.has_unseen_features?(current_user.id),
      release_notes_link: AdminDashboardGeneralData.fetch_cached_stats["release_notes_link"],
    }

    mark_new_features_as_seen

    render json: data
  end

  def toggle_feature
    UpcomingChanges::Toggle.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:setting_is_available) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end

  def update_reports_section
    AdminDashboard::Reports::LayoutUpdater.call(
      items: parse_reports_items_payload,
      guardian: guardian,
    )
    head :no_content
  end

  def available_reports
    search = params[:search]
    cursor = params.permit(cursor: %i[title key])[:cursor]&.to_h&.symbolize_keys
    enabled = AdminDashboard::Reports::Section.build(guardian: guardian, search: search)[:items]
    listing = AdminDashboard::Reports::Listing.call(cursor: cursor, search: search)

    render json: {
             providers: listing[:providers],
             enabled: enabled,
             available: listing[:items],
             has_more: listing[:has_more],
             cursor: listing[:cursor],
           }
  end

  def bulk_reports
    permitted_filters = params.permit(filters: BULK_REPORTS_FILTER_KEYS).fetch(:filters, nil)
    filters = permitted_filters.present? ? permitted_filters.to_h.symbolize_keys : {}

    hijack do
      render_json_dump(
        AdminDashboard::Reports::BulkFetch.call(
          items: parse_reports_items_payload,
          filters: filters,
          guardian: guardian,
        ),
      )
    end
  end

  private

  def serialized_problems
    serialize_data(AdminNotice.problem.order(:id), AdminNoticeSerializer)
  end

  def dashboard_sections_payload
    visible_ids = AdminDashboardSectionConfiguration.visible_section_ids
    data = {
      sections:
        AdminDashboardSectionLoader.build(
          section_ids: visible_ids,
          current_user: current_user,
          start_date: params[:start_date],
          end_date: params[:end_date],
        ),
      problems: serialized_problems,
    }
    if current_user.admin?
      data[:configuration] = { sections: AdminDashboardSectionConfiguration.sections }
    end
    data
  end

  def mark_new_features_as_seen
    DiscourseUpdates.mark_new_features_as_seen(current_user.id)
  end

  def ensure_dashboard_improvements_enabled
    raise Discourse::NotFound if !dashboard_improvements?
  end

  def dashboard_improvements?
    dashboard_improvements_enabled =
      UpcomingChanges.enabled_for_user?(:dashboard_improvements, current_user)

    if params[:version] == "alt"
      !dashboard_improvements_enabled
    else
      dashboard_improvements_enabled
    end
  end

  def parse_reports_items_payload
    raise Discourse::InvalidParameters.new(:items) if !params[:items].is_a?(Array)
    if params[:items].size > AdminDashboardReport::VISIBLE_CAP
      raise Discourse::InvalidParameters.new(:items)
    end

    params
      .permit(items: %i[source identifier])
      .fetch(:items, [])
      .map do |entry|
        source = entry[:source]
        identifier = entry[:identifier]
        raise Discourse::InvalidParameters.new(:items) if source.blank? || identifier.blank?
        { source: source.to_s, identifier: identifier.to_s }
      end
  end
end
