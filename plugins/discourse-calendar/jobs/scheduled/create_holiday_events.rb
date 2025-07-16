# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::CreateHolidayEvents < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return if !SiteSetting.calendar_enabled
      return if !SiteSetting.calendar_automatic_holidays_enabled

      return unless topic_id = SiteSetting.holiday_calendar_topic_id.presence

      require "holidays" if !defined?(Holidays)

      today = Date.today

      regions_and_user_ids = Hash.new { |h, k| h[k] = [] }

      UserCustomField
        .where(name: ::DiscourseCalendar::REGION_CUSTOM_FIELD)
        .pluck(:user_id, :value)
        .each { |user_id, region| regions_and_user_ids[region] << user_id if region.present? }

      usernames =
        User
          .real
          .activated
          .not_suspended
          .not_silenced
          .where(id: regions_and_user_ids.values.flatten)
          .pluck(:id, :username)
          .to_h

      timezones =
        UserOption
          .where(user_id: usernames.keys)
          .where.not(timezone: nil)
          .pluck(:user_id, :timezone)
          .map do |user_id, timezone|
            [
              user_id,
              (
                begin
                  TZInfo::Timezone.get(timezone)
                rescue StandardError
                  nil
                end
              ),
            ]
          end
          .to_h

      # Remove holidays for deactivated/suspended/silenced users
      CalendarEvent.where(post_id: nil).where.not(user_id: usernames.keys).destroy_all

      # Remove future holidays when users changed their region
      CalendarEvent
        .joins(user: :_custom_fields)
        .where(post_id: nil)
        .where("start_date > ?", today)
        .where("user_custom_fields.name = ?", ::DiscourseCalendar::REGION_CUSTOM_FIELD)
        .where("LENGTH(COALESCE(user_custom_fields.value, '')) > 0")
        .where("user_custom_fields.value != calendar_events.region")
        .destroy_all

      regions_and_user_ids.each do |region, user_ids|
        DiscourseCalendar::Holiday
          .find_holidays_for(
            region_code: region,
            start_date: today,
            end_date: 6.months.from_now,
            show_holiday_observed_on_dates: true,
          )
          .filter { |holiday| (1..5) === holiday[:date].wday && holiday[:disabled] === false }
          .each do |holiday|
            user_ids.each do |user_id|
              next unless usernames[user_id]

              date = holiday[:date]

              if tz = timezones[user_id]
                date = holiday[:date].in_time_zone(tz)
                date = date.change(hour_adjustment) if hour_adjustment
              end

              event =
                CalendarEvent
                  .where(topic_id: topic_id, user_id: user_id, description: holiday[:name])
                  .where(
                    "start_date >= :from AND start_date <= :to",
                    from: date - 1.day,
                    to: date + 1.day,
                  )
                  .first_or_initialize

              event.update!(
                topic_id: topic_id,
                user_id: user_id,
                description: holiday[:name],
                start_date: date,
                region: region,
                username: usernames[user_id],
                timezone: tz&.name,
              )
            end
          end
      end
    end

    def hour_adjustment
      if SiteSetting.all_day_event_start_time.empty? || SiteSetting.all_day_event_end_time.empty?
        return
      end

      @holiday_hour ||=
        begin
          split = SiteSetting.all_day_event_start_time.split(":")
          { hour: split.first, min: split.second }
        end
    end
  end
end
