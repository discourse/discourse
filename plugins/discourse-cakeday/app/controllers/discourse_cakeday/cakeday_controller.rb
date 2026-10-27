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

    def cakedays_by(column_sql, at_least_one_year_old: false, apply_timezone: false)
      more_params = { page: @page + 1, filter: params[:filter] }

      today =
        begin
          Time.zone.now.in_time_zone(@timezone)
        rescue ArgumentError
          Time.zone.now
        end.to_date

      indexed_column_sql = column_sql

      if apply_timezone && @timezone.present? && @timezone != "UTC"
        if (iana_timezone = ActiveSupport::TimeZone[@timezone]&.tzinfo&.canonical_identifier)
          quoted_timezone = ActiveRecord::Base.connection.quote(iana_timezone)
          column_sql = "#{column_sql} AT TIME ZONE 'UTC' AT TIME ZONE #{quoted_timezone}"
        end
      end

      if at_least_one_year_old
        @users = @users.where("EXTRACT(YEAR FROM #{column_sql}) < ?", today.year)
      end

      # dates are moved to a leap year so that February 29th can be part of a range
      from, to =
        case params[:filter]
        when "today", "tomorrow"
          date = params[:filter] == "today" ? today : today + 1.day
          from = to = in_leap_year(date)
          # when the current year is not a leap year, we consider February 29th to be March 1st
          from -= 1.day if !date.leap? && to == Date.new(2000, 3, 1)
          [from, to]
        when "upcoming"
          [in_leap_year(today + 2.days), in_leap_year(today + 9.days)]
        else # month
          more_params[:month] = @month
          first = Date.new(2000, @month, 1)
          [first, first.end_of_month]
        end

      @users = where_month_day_between(@users, month_day_sql(column_sql), from, to)

      if column_sql != indexed_column_sql
        # the timezone shifts the date by less than a day, so the UTC date can use the index to narrow down the users
        @users =
          where_month_day_between(
            @users,
            month_day_sql(indexed_column_sql),
            previous_day(from),
            next_day(to),
          )
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
          .order(
            # the upcoming range can wrap around the end of the year
            "#{month_day_sql(column_sql)} < #{month_day(from)} ASC",
            "TO_CHAR(#{column_sql}, 'MMDDYYYY') ASC",
          )
          .order(tie_breaker)
          .limit(PAGE_SIZE)
          .offset(PAGE_SIZE * @page)

      [@users, total, more_params]
    end

    def month_day_sql(column_sql)
      "(EXTRACT(MONTH FROM #{column_sql}) * 100 + EXTRACT(DAY FROM #{column_sql}))"
    end

    def month_day(date)
      date.month * 100 + date.day
    end

    def in_leap_year(date)
      Date.new(2000, date.month, date.day)
    end

    # in non-leap years, February 28th and March 1st are next to each other
    def previous_day(date)
      day = date - 1.day
      day.month == 2 && day.day == 29 ? day - 1.day : day
    end

    def next_day(date)
      day = date + 1.day
      day.month == 2 && day.day == 29 ? day + 1.day : day
    end

    def where_month_day_between(users, month_day_sql, from, to)
      operator = month_day(from) <= month_day(to) ? "AND" : "OR"
      users.where(
        "#{month_day_sql} >= :from #{operator} #{month_day_sql} <= :to",
        from: month_day(from),
        to: month_day(to),
      )
    end
  end
end
