# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a rewind for a username/year.
  #
  # @example
  #  ::DiscourseRewind::Rewind::Fetch.call(
  #    guardian: guardian,
  #    params: { user: User, for_user_username: 'codinghorror' }
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
      #Action::FavoriteGifs,
      Action::Assignments,
      Action::Invites,
    ]

    params do
      attribute :user
      attribute :for_user_username, :string
    end

    model :for_user
    model :year
    model :date
    model :all_reports
    model :reports
    model :total_available

    private

    def fetch_for_user(params:, guardian:)
      return guardian.user if params.for_user_username.blank?

      user = User.find_by(username: params.for_user_username)
      return if user.nil?

      if guardian.user.id != user.id
        if !user.discourse_rewind_and_profile_public?
          return if !guardian.user.admin?
        end
      end

      user
    end

    def fetch_year
      current_date = Time.zone.now
      current_month = current_date.month
      current_year = current_date.year

      case current_month
      when 1
        current_year - 1
      when 12
        current_year
      else
        # Otherwise it's impossible to test in browser locally unless you're
        # in December or January
        if Rails.env.development?
          current_year
        else
          false
        end
      end
    end

    def fetch_date(params:, year:)
      Date.new(year).all_year
    end

    def fetch_all_reports(date:, for_user:, year:)
      reports = load_reports_from_cache(for_user.username, year)

      if !reports
        reports =
          REPORTS.filter_map do |report|
            report.call(date:, user: for_user)
          rescue StandardError
            nil
          end
        cache_reports(for_user.username, year, reports)
      end

      reports
    end

    def fetch_reports(all_reports:)
      all_reports.first(INITIAL_REPORT_COUNT)
    end

    def fetch_total_available(all_reports:)
      all_reports.size
    end
  end
end
