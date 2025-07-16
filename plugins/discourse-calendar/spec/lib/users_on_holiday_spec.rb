# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::UsersOnHoliday do
  it "returns users on holiday" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-02")

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

    usernames = users_on_holiday.values.map { |u| u[:username] }
    expect(usernames).to contain_exactly(event1.username, event2.username, event3.username)
  end

  it "returns empty list if no one is on holiday" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-02")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-03")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-04")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-05")

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

    expect(users_on_holiday).to be_empty
  end

  it "ignore holidays without usernames" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-01", username: nil)

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3])

    usernames = users_on_holiday.values.map { |u| u[:username] }
    expect(usernames).to contain_exactly(event1.username, event2.username)
  end

  it "don't pick up holidays in the future" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-02")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-03")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-04")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-05")

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

    expect(users_on_holiday).to be_empty
  end

  context "with subsequent and intersected holidays" do
    it "chooses the farthest end date if a user has several holidays" do
      user = Fabricate(:user)
      biggest_end_date = "2000-01-04"
      #
      # event1  ▭▭▭▭
      # event2  ▭▭▭▭▭▭▭▭
      # event3  ▭▭▭▭▭▭▭▭▭▭▭▭
      #                     ↑
      event1 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: "2000-01-02")
      event2 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: "2000-01-03")
      event3 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: biggest_end_date)

      freeze_time Time.utc(2000, 1, 1, 8, 0)
      users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3])

      expect(users_on_holiday.length).to be(1)
      expect(users_on_holiday.values[0][:ends_at]).to eq(biggest_end_date)
    end

    it "chooses the farthest end date if a user has a short holiday in the middle of a long vacation" do
      user = Fabricate(:user)
      biggest_end_date = "2000-01-07"
      #
      # event1  ▭▭▭▭▭▭▭▭
      # event2     ▭    ↑
      #
      event1 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: biggest_end_date)
      event2 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-04", end_date: "2000-01-05")

      freeze_time Time.utc(2000, 1, 1, 8, 0)
      users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2])

      expect(users_on_holiday.length).to be(1)
      expect(users_on_holiday.values[0][:ends_at]).to eq(biggest_end_date)
    end

    it "chooses the farthest end date if a user has several subsequent holidays" do
      user = Fabricate(:user)
      farthest_end_date = "2000-01-04"
      #
      # event1  ▭▭▭▭
      # event2      ▭▭▭▭
      # event3          ▭▭▭▭
      # event4              ↑        ▭▭▭▭
      #
      event1 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: "2000-01-02")
      event2 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-02", end_date: "2000-01-03")
      event3 =
        Fabricate(
          :calendar_event,
          user: user,
          start_date: "2000-01-03",
          end_date: farthest_end_date,
        )
      # this event isn't a part of the chain of subsequent holidays
      event4 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-08", end_date: "2000-01-10")

      freeze_time Time.utc(2000, 1, 1, 8, 0)
      users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

      expect(users_on_holiday.length).to be(1)
      expect(users_on_holiday.values[0][:ends_at]).to eq(farthest_end_date)
    end

    it "chooses the farthest end date if a user has several subsequent holidays with intersections" do
      user = Fabricate(:user)
      farthest_end_date = "2000-01-04 08:00:00"
      #
      # event1  ▭▭▭▭
      # event2    ▭▭▭▭
      # event3       ▭▭▭▭
      # event4           ↑       ▭▭▭▭
      #
      event1 =
        Fabricate(
          :calendar_event,
          user: user,
          start_date: "2000-01-01 08:00:00",
          end_date: "2000-01-02 10:00:00",
        )
      event2 =
        Fabricate(
          :calendar_event,
          user: user,
          start_date: "2000-01-02 08:00:00",
          end_date: "2000-01-03 12:00:00",
        )
      event3 =
        Fabricate(
          :calendar_event,
          user: user,
          start_date: "2000-01-03 08:00:00",
          end_date: farthest_end_date,
        )
      # this event isn't a part of the chain of subsequent holidays
      event4 =
        Fabricate(:calendar_event, user: user, start_date: "2000-01-08", end_date: "2000-01-10")

      freeze_time Time.utc(2000, 1, 1, 8, 0)
      users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

      expect(users_on_holiday.length).to be(1)
      expect(users_on_holiday.values[0][:ends_at]).to eq(farthest_end_date)
    end
  end
end
