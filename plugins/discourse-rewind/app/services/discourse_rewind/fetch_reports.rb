# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a rewind for a username/year.
  #
  # @example
  #  ::DiscourseRewind::Rewind::Fetch.call(
  #    guardian: guardian,
  #    params: { year: 2023, username: 'codinghorror' }
  #  )
  #
  class FetchReports
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :year of the rewind
    #   @option params [Integer] :username of the rewind
    #   @return [Service::Base::Context]

    CACHE_DURATION = Rails.env.development? ? 10.seconds : 5.minutes

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
      Action::FavoriteGifs,
      Action::Assignments,
      Action::Invites,
    ]

    model :year
    model :date
    model :reports

    private

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

    def fetch_reports(date:, guardian:, year:)
      key = "rewind:#{guardian.user.username}:#{year}"
      reports = Discourse.redis.get(key)

      if !reports
        reports =
          REPORTS.map { |report| report.call(date:, user: guardian.user, guardian:) }.compact
        Discourse.redis.setex(key, CACHE_DURATION, MultiJson.dump(reports))
      else
        reports = MultiJson.load(reports, symbolize_keys: true)
      end

      reports
    end
  end
end
