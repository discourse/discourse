# frozen_string_literal: true

module DiscourseRewind
  module FetchReportsHelper
    extend self

    REWIND_REPORT_VERSION = "2"
    CACHE_DURATION = Rails.env.development? ? 10.seconds : 3.days

    def cache_key(username, year)
      "rewind:#{username}:#{year}:v#{REWIND_REPORT_VERSION}"
    end

    def single_report_cache_key(username, year, name)
      "rewind:#{username}:#{year}:#{name}:v#{REWIND_REPORT_VERSION}"
    end

    def load_reports_from_cache(username, year)
      reports = Discourse.redis.get(cache_key(username, year))
      return nil if !reports
      MultiJson.load(reports, symbolize_keys: true)
    end

    def load_single_report_from_cache(username, year, name)
      report = Discourse.redis.get(single_report_cache_key(username, year, name))
      return nil if !report
      MultiJson.load(report, symbolize_keys: true)
    end

    # NOTE: This only caches the first INITIAL_REPORT_COUNT reports.
    def cache_reports(username, year, reports)
      Discourse.redis.setex(cache_key(username, year), CACHE_DURATION, MultiJson.dump(reports))
    end

    def cache_single_report(username, year, name, report)
      Discourse.redis.setex(
        single_report_cache_key(username, year, name),
        CACHE_DURATION,
        MultiJson.dump(report),
      )
    end

    def fetch_for_user(guardian:, params:)
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
          nil
        end
      end
    end
  end
end
