# frozen_string_literal: true

class UserNotificationScheduleProcessor
  attr_accessor :schedule, :user, :timezone_name

  def initialize(schedule)
    @schedule = schedule
    @user = schedule.user
    @timezone_name = user.user_option.timezone
  end

  def create_do_not_disturb_timings
    local_time = Time.now.in_time_zone(timezone_name)

    create_timings_for(local_time, days: 2)
  end

  def self.create_do_not_disturb_timings_for(schedule)
    processor = UserNotificationScheduleProcessor.new(schedule)
    processor.create_do_not_disturb_timings
  end

  private

  def create_timings_for(local_time, days: 0, previous_timing: nil)
    weekday = transform_wday(local_time.wday)
    start_minute = schedule["day_#{weekday}_start_time"]
    end_minute = schedule["day_#{weekday}_end_time"]

    previous_timing = find_previous_timing(local_time) if previous_timing.nil? && start_minute != 0

    if start_minute > 0
      previous_timing.ends_at = utc_time_at_minute(local_time, start_minute - 1)
      if previous_timing.id
        previous_timing.save
      else
        user.do_not_disturb_timings.find_or_create_by(previous_timing.attributes.except("id"))
      end

      next_timing =
        user.do_not_disturb_timings.new(
          starts_at: utc_time_at_minute(local_time, end_minute),
          scheduled: true,
        )
      save_timing_and_continue(local_time, next_timing, days)
    else
      save_timing_and_continue(local_time, previous_timing, days)
    end
  end

  private

  def find_previous_timing(local_time)
    # Try and find a previously scheduled dnd timing that we can extend if the
    # ends_at is at the previous midnight. fallback to a new timing if not.
    previous =
      user.do_not_disturb_timings.find_by(
        ends_at: (local_time - 1.day).end_of_day.utc,
        scheduled: true,
      )
    previous ||
      user.do_not_disturb_timings.new(starts_at: local_time.beginning_of_day.utc, scheduled: true)
  end

  def save_timing_and_continue(local_time, timing, days)
    if days == 0
      if timing
        timing.ends_at = local_time.end_of_day.utc
        user.do_not_disturb_timings.find_or_create_by(timing.attributes.except("id"))
      end
      user.publish_do_not_disturb(ends_at: user.do_not_disturb_until)
    else
      create_timings_for(local_time + 1.day, days: days - 1, previous_timing: timing)
    end
  end

  def utc_time_at_minute(base_time, total_minutes)
    hour = total_minutes / 60
    minute = total_minutes % 60
    Time.new(
      base_time.year,
      base_time.month,
      base_time.day,
      hour,
      minute,
      0,
      base_time.formatted_offset,
    ).utc
  end

  def transform_wday(wday)
    wday == 0 ? 6 : wday - 1
  end
end
