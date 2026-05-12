# frozen_string_literal: true

class Admin::DashboardController < Admin::StaffController
  BULK_REPORTS_FILTER_KEYS = %i[start_date end_date].freeze

  before_action :ensure_dashboard_improvements_enabled, only: %i[bulk_reports]

  def index
    if SiteSetting.dashboard_improvements
      visible_ids = AdminDashboardSectionConfiguration.visible_section_ids
      data = { sections: visible_ids.map { |id| { id: id, data: section_data(id) } } }
      if current_user.admin?
        data[:configuration] = { sections: AdminDashboardSectionConfiguration.sections }
      end
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

  def bulk_reports
    items = parse_items
    filters = parse_filters

    hijack do
      results = collect_results(items, filters)
      render_json_dump(items: results)
    end
  end

  private

  def section_data(id)
    case id
    when "highlights"
      AdminDashboardHighlights.build(start_date: params[:start_date], end_date: params[:end_date])
    when "traffic"
      AdminDashboardSiteTraffic.build(start_date: params[:start_date], end_date: params[:end_date])
    when "reports"
      AdminDashboardReportsSection.build(guardian: guardian)
    end
  end

  def mark_new_features_as_seen
    DiscourseUpdates.mark_new_features_as_seen(current_user.id)
  end

  def ensure_dashboard_improvements_enabled
    raise Discourse::NotFound if !SiteSetting.dashboard_improvements
  end

  def parse_items
    raise Discourse::InvalidParameters.new(:items) if !params[:items].is_a?(Array)
    if params[:items].size > AdminDashboardReport::VISIBLE_CAP
      raise Discourse::InvalidParameters.new(:items)
    end

    entries = params.permit(items: %i[source identifier]).fetch(:items, [])
    entries.map do |entry|
      source = entry[:source]
      identifier = entry[:identifier]
      raise Discourse::InvalidParameters.new(:items) if source.blank? || identifier.blank?
      { source: source.to_s, identifier: identifier.to_s }
    end
  end

  def parse_filters
    permitted = params.permit(filters: BULK_REPORTS_FILTER_KEYS).fetch(:filters, nil)
    permitted.present? ? permitted.to_h.symbolize_keys : {}
  end

  def collect_results(items, filters)
    per_source =
      items
        .group_by { |i| i[:source] }
        .each_with_object({}) do |(source, group), hash|
          provider = AdminDashboard::Reports::Registry.provider_for(source)
          next if provider.nil?

          identifiers = group.map { |i| i[:identifier] }
          hash[source] = provider.fetch_many(identifiers, guardian:, filters:)
        end

    items.map do |item|
      {
        source: item[:source],
        identifier: item[:identifier],
        data: per_source.dig(item[:source], item[:identifier]),
      }
    end
  end
end
