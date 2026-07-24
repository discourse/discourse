# frozen_string_literal: true

class AdminDashboardSectionLoader
  def self.build(section_ids:, current_user:, start_date:, end_date:)
    new(
      section_ids: section_ids,
      current_user: current_user,
      start_date: start_date,
      end_date: end_date,
    ).build
  end

  def initialize(section_ids:, current_user:, start_date:, end_date:)
    @section_ids = section_ids
    @current_user = current_user
    @start_date = start_date
    @end_date = end_date
  end

  def build
    section_ids.map { |id| build_section(id) }
  end

  private

  attr_reader :section_ids, :current_user, :start_date, :end_date

  def build_section(id)
    { id: id, data: section_data(id, current_user) }
  rescue StandardError => e
    failed_result(id: id, error: e)
  end

  def failed_result(result)
    Discourse.warn_exception(
      result[:error],
      message: "Failed to build admin dashboard section",
      env: {
        section_id: result[:id],
      },
    )

    { id: result[:id], data: nil, error: true }
  end

  def section_data(id, user)
    case id
    when "highlights"
      AdminDashboardHighlights.build(start_date: start_date, end_date: end_date)
    when "traffic"
      AdminDashboardSiteTraffic.build(
        start_date: start_date,
        end_date: end_date,
        guardian: user.guardian,
      )
    when "engagement"
      AdminDashboardEngagement.build(start_date: start_date, end_date: end_date, current_user: user)
    when "reports"
      reports_section_data(user)
    when "search"
      AdminDashboardSearch.build(start_date: start_date, end_date: end_date)
    else
      section = DiscoursePluginRegistry.admin_dashboard_sections.find { |s| s[:id] == id }
      section&.dig(:loader)&.call(start_date: start_date, end_date: end_date, current_user: user)
    end
  end

  def reports_section_data(user)
    section = AdminDashboard::Reports::Section.build(guardian: user.guardian)
    fetched_items =
      AdminDashboard::Reports::BulkFetch.call(
        items: section[:items],
        filters: { start_date:, end_date: }.compact,
        guardian: user.guardian,
      ).fetch(:items)
    payloads = fetched_items.index_by { |item| item[:key] }

    { items: section[:items].map { |item| item.merge(payload: payloads.dig(item[:key], :data)) } }
  end
end
