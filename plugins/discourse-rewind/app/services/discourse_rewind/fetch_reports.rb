# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a rewind for a username/year.
  #
  # @example
  #  ::DiscourseRewind::Rewind::Fetch.call(
  #    guardian: guardian,
  #    params: { for_user_username: 'codinghorror' }
  #  )
  #
  class FetchReports
    include Service::Base
    include DiscourseRewind::FetchReportsHelper

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [String] :for_user_username (optional) username of the user to see the rewind for, otherwise the guardian user is used
    #   @return [Service::Base::Context]

    INITIAL_REPORT_COUNT = 3

    # The order here controls the order of reports in the UI,
    # so be careful when moving these around.
    #
    # NOTE: When changing any report implementations, please
    # also update FetchReportsHelper::REWIND_REPORT_VERSION
    # to invalidate caches.
    REPORTS = [
      Action::TopWords,
      Action::ReadingTime,
      Action::WritingAnalysis,
      Action::Reactions,
      Action::Fbff,
      Action::MostViewedTags,
      Action::MostViewedCategories,
      Action::BestTopics,
      Action::BestPosts,
      Action::ActivityCalendar,
      Action::TimeOfDayActivity,
      Action::NewUserInteractions,
      Action::ChatUsage,
      Action::AiUsage,
      Action::Assignments,
      Action::Invites,
    ]

    params { attribute :for_user_username, :string }

    model :for_user # see FetchReportsHelper#fetch_for_user
    model :year # see FetchReportsHelper#fetch_year
    model :date
    model :reports
    model :total_available

    private

    def fetch_date(params:, year:)
      Date.new(year).all_year
    end

    def fetch_reports(date:, for_user:, year:)
      reports = load_reports_from_cache(for_user.username, year)

      if !reports
        reports =
          REPORTS
            .first(INITIAL_REPORT_COUNT)
            .filter_map do |report|
              report.call(date:, user: for_user)
            rescue StandardError
              nil
            end
        cache_reports(for_user.username, year, reports)
      end

      reports
    end

    def fetch_total_available
      REPORTS.size
    end
  end
end
