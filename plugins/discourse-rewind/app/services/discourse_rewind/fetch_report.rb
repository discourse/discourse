# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a single report by index.
  #
  # @example
  #  ::DiscourseRewind::FetchReport.call(
  #    guardian: guardian,
  #    params: { index: 3 }
  #  )
  #
  class FetchReport
    include Service::Base

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
      return guardian.user if params.for_user_username.blank?

      user = User.find_by(username: params.for_user_username)
      return if user.nil?

      if guardian.user.id != user.id
        return if !user.user_option.discourse_rewind_share_publicly
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
        if Rails.env.development?
          current_year
        else
          false
        end
      end
    end

    def fetch_all_reports(for_user:, year:)
      key = "rewind:#{for_user.username}:#{year}"
      reports = Discourse.redis.get(key)
      return nil unless reports

      MultiJson.load(reports, symbolize_keys: true)
    end

    def fetch_report(all_reports:, params:)
      all_reports[params.index]
    end
  end
end
