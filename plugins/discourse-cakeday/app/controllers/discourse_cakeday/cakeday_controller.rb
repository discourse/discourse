# frozen_string_literal: true

module DiscourseCakeday
  class CakedayController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :setup_params

    private

    PAGE_SIZE = 48

    def setup_params
      @page = params[:page].to_i.clamp(0..)
      @month = params[:month].to_i.clamp(1..12)
      @users =
        User
          .real
          .activated
          .not_staged
          .not_silenced
          .not_suspended
          .joins(:user_option)
          .where("user_options.hide_profile = ?", false)
      @timezone = current_user&.user_option&.timezone
    end

    def cakedays_by(column_sql, at_least_one_year_old: false)
      more_params = { page: @page + 1, filter: params[:filter] }

      today =
        begin
          Time.zone.now.in_time_zone(@timezone)
        rescue ArgumentError
          Time.zone.now
        end.to_date

      if at_least_one_year_old
        @users = @users.where("EXTRACT(YEAR FROM #{column_sql}) < ?", today.year)
      end

      # when the current year is not a leap year, we consider February 29th to be March 1st
      date_sql = <<~SQL
        TO_CHAR(#{column_sql}, 'MMDD') = :date OR (
          NOT :leap AND
          :date = '0301' AND
          TO_CHAR(#{column_sql}, 'MMDD') = '0229'
        )
      SQL

      @users =
        case params[:filter]
        when "today"
          @users.where(date_sql, leap: today.leap?, date: mmdd(today))
        when "tomorrow"
          tomorrow = today + 1.day
          @users.where(date_sql, leap: tomorrow.leap?, date: mmdd(tomorrow))
        when "upcoming"
          from = today + 2.days
          to = from + 1.week
          @users.where("TO_CHAR(#{column_sql}, 'MMDD') BETWEEN ? AND ?", mmdd(from), mmdd(to))
        else # month
          more_params[:month] = @month
          @users.where("EXTRACT(MONTH FROM #{column_sql}) = ?", @month)
        end

      total = @users.count

      # when the cakedate is the same, we order based on how the data is displayed
      tie_breaker =
        if SiteSetting.prioritize_username_in_ux
          :username_lower
        else
          "COALESCE(NULLIF(LOWER(TRIM(users.name)), ''), users.username_lower) ASC"
        end

      @users =
        @users
          .select(:id, :username, :name, :title, :uploaded_avatar_id, "#{column_sql} cakedate")
          .order("TO_CHAR(#{column_sql}, 'MMDDYYYY') ASC")
          .order(tie_breaker)
          .limit(PAGE_SIZE)
          .offset(PAGE_SIZE * @page)

      [@users, total, more_params]
    end

    def mmdd(date)
      date.strftime("%m%d")
    end
  end
end
