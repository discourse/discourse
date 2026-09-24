# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a page of the reports of a rewind.
  #
  # @example
  #  ::DiscourseRewind::FetchReports.call(
  #    guardian: guardian,
  #    params: { for_user_username: 'codinghorror', offset: 3 }
  #  )
  #
  class FetchReports
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [String] :for_user_username (optional) username of the user to see the rewind for, otherwise the guardian user is used
    #   @option params [Integer] :offset (optional) position of the first report of the page, defaults to 0
    #   @return [Service::Base::Context]

    PAGE_SIZE = 3
    REWIND_REPORT_VERSION = "3"
    CACHE_DURATION = Rails.env.development? ? 10.seconds : 3.days

    # The order here controls the order of reports in the UI,
    # so be careful when moving these around.
    #
    # NOTE: When changing any report implementations, please
    # also update REWIND_REPORT_VERSION
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

    def self.enabled_reports
      REPORTS.select(&:enabled?)
    end

    params do
      attribute :for_user_username, :string
      attribute :offset, :integer, default: 0

      validates :offset,
                numericality: {
                  greater_than_or_equal_to: 0,
                  less_than: ->(_) { FetchReports.enabled_reports.size },
                }
    end

    model :for_user
    model :year
    model :reports
    model :total_available

    private

    def fetch_for_user(guardian:, params:)
      return guardian.user if params.for_user_username.blank?

      user = User.find_by_username(params.for_user_username)
      return if !user

      if guardian.is_me?(user) || guardian.is_admin? || user.discourse_rewind_and_profile_public?
        user
      end
    end

    def fetch_year
      DiscourseRewind.rewind_year if DiscourseRewind.rewind_period?
    end

    def fetch_reports(params:, for_user:, year:, guardian:)
      self.class.enabled_reports[params.offset, PAGE_SIZE].map do |report_class|
        fetch_report(report_class, for_user:, year:, guardian:)
      end
    end

    def fetch_total_available
      self.class.enabled_reports.size
    end

    def fetch_report(report_class, for_user:, year:, guardian:)
      name = report_class.name.demodulize
      key = "rewind:#{for_user.id}:#{year}:#{name}:v#{REWIND_REPORT_VERSION}"
      report =
        Discourse
          .cache
          .fetch(key, expires_in: CACHE_DURATION) do
            report_class.call(date: Time.zone.local(year).all_year, user: for_user)
          rescue StandardError => e
            Discourse.warn_exception(e, message: "Rewind report #{name} failed")
            return
          end

      return if report&.dig(:data).blank?

      report = report_class.filter_for_viewer(report, guardian:, for_user:)
      report if report&.dig(:data).present?
    end
  end
end
