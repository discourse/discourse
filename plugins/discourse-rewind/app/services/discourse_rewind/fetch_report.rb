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

    model :for_user
    model :year
    model :all_reports
    model :report

    private

    def fetch_for_user(params:, guardian:)
      rewind_for_user(guardian:, params:)
    end

    def fetch_year
      rewind_year
    end

    def fetch_all_reports(for_user:, year:)
      load_reports_from_cache(for_user.username, year)
    end

    def fetch_report(all_reports:, params:)
      all_reports[params.index]
    end
  end
end
