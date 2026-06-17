# frozen_string_literal: true

class AdminDashboardSectionLoader
  POOL_SIZE = 4

  def self.build(section_ids:, current_user:, start_date:, end_date:)
    new(
      section_ids: section_ids,
      current_user: current_user,
      start_date: start_date,
      end_date: end_date,
    ).build
  end

  def self.thread_pool
    @thread_pool ||=
      Scheduler::ThreadPool.new(min_threads: 0, max_threads: POOL_SIZE, idle_time: 30)
  end

  def initialize(section_ids:, current_user:, start_date:, end_date:)
    @section_ids = section_ids
    @user_id = current_user.id
    @start_date = start_date
    @end_date = end_date
    @locale = I18n.locale
  end

  def build
    results = Queue.new

    section_ids.each do |id|
      self.class.thread_pool.post do
        I18n.with_locale(locale) do
          user = User.find(user_id)
          results << { id: id, data: section_data(id, user) }
        rescue StandardError => e
          results << { id: id, error: e }
        end
      end
    end

    results_by_id = {}

    section_ids.size.times do
      result = results.pop
      raise result[:error] if result[:error]

      results_by_id[result[:id]] = result
    end

    section_ids.map { |id| results_by_id.fetch(id) }
  end

  private

  attr_reader :section_ids, :user_id, :start_date, :end_date, :locale

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
    end
  end
end
