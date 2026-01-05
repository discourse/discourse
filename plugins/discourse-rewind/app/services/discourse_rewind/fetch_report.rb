# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a single report by index.
  #
  # NOTE: When changing any report implementations, please
  # also update FetchReportsHelper::REWIND_REPORT_VERSION
  # to invalidate caches.
  #
  # @example
  #  ::DiscourseRewind::FetchReport.call(
  #    guardian: guardian,
  #    params: { index: 3, for_user_username: 'codinghorror' }
  #  )
  #
  class FetchReport
    include Service::Base
    include DiscourseRewind::FetchReportsHelper

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :index of the report
    #   @option params [String] :for_user_username (optional) username of the user to see the rewind for, otherwise the guardian user is used
    #   @return [Service::Base::Context]

    params do
      attribute :index, :integer
      attribute :for_user_username, :string

      validates :index, presence: true, numericality: { greater_than_or_equal_to: 0 }
    end

    model :for_user # see FetchReportsHelper#fetch_for_user
    model :year # see FetchReportsHelper#fetch_year
    model :date
    model :report

    private

    def fetch_date(params:, year:)
      Date.new(year).all_year
    end

    def fetch_report(params:, for_user:, year:, date:)
      report_class = FetchReports::REPORTS[params.index]
      return if !report_class

      report_name = report_class.name.demodulize
      report = load_single_report_from_cache(for_user.username, year, report_name)
      if !report
        report = report_class.call(date:, user: for_user)
        cache_single_report(for_user.username, year, report_name, report.as_json)
      end
      report
    end
  end
end
