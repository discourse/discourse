# frozen_string_literal: true

module DiscourseCalendar
  class UsersOnHoliday
    def self.from(calendar_events)
      calendar_events
        .filter { |e| e.user_id.present? && e.username.present? }
        .filter { |e| e.underway? || e.in_future? }
        .group_by(&:user_id)
        .map { |_, events| current_holiday(events) }
        .compact
        .to_h
    end

    private

    def self.current_holiday(user_events)
      ends_at = holiday_ends_at(user_events)
      return nil unless ends_at

      [user_events[0].user_id, { username: user_events[0].username, ends_at: ends_at }]
    end

    # If a user has several holidays one after another
    # we want to show the farthest end date.
    #
    # Let's say today is Monday and I am sick,
    # and I also have days off from Tuesday to Friday:
    #
    # sick      ▭
    # days off   ▭▭▭▭
    #
    # We want to show Friday as an end date of my holiday.
    #
    # This algorithm also works in case the holidays intersect,
    # like this:
    #
    # event_1  ▭▭▭▭
    # event_2    ▭▭▭▭
    # event_3       ▭▭▭▭
    #
    # or like this:
    #
    # event_1  ▭▭▭▭
    # event_2  ▭▭▭▭▭▭▭▭
    # event_3    ▭▭▭▭▭▭▭▭▭▭
    #
    # or like this:
    #
    # event_1  ▭▭▭▭▭▭▭▭▭▭
    # event_2      ▭
    #
    def self.holiday_ends_at(events)
      sorted_events = events.sort_by(&:start_date)
      return nil if sorted_events.first.in_future?
      return sorted_events.first.ends_at if events.count == 1

      result = sorted_events.first.ends_at
      sorted_events.each_cons(2) do |pair|
        if pair[0].ends_at < pair[1].start_date
          return result
        elsif pair[1].ends_at > result
          result = pair[1].ends_at
        end
      end

      result
    end
  end
end
