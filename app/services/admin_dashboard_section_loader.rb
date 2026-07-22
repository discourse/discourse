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
    section_ids.map do |id|
      { id: id, data: section_data(id, current_user) }
    rescue StandardError => error
      Discourse.warn_exception(
        error,
        message: "Failed to build admin dashboard section",
        env: {
          section_id: id,
        },
      )
      { id: id, data: nil, error: true }
    end
  end

  private

  attr_reader :section_ids, :current_user, :start_date, :end_date

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
      AdminDashboard::Reports::Section.build(guardian: user.guardian)
    when "search"
      AdminDashboardSearch.build(start_date: start_date, end_date: end_date)
    else
      section = DiscoursePluginRegistry.admin_dashboard_sections.find { |s| s[:id] == id }
      section&.dig(:loader)&.call(start_date: start_date, end_date: end_date, current_user: user)
    end
  end
end
