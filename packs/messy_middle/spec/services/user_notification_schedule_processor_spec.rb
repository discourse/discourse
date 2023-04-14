# frozen_string_literal: true

RSpec.describe UserNotificationScheduleProcessor do
  include ActiveSupport::Testing::TimeHelpers

  fab!(:user) { Fabricate(:user) }
  let(:standard_schedule) do
    schedule =
      UserNotificationSchedule.create({ user: user }.merge(UserNotificationSchedule::DEFAULT))
    schedule.enabled = true
    schedule.save
    schedule
  end

  describe "#create_do_not_disturb_timings" do
    [
      { timezone: "UTC", offset: "+00:00" },
      { timezone: "America/Chicago", offset: "-06:00" },
      { timezone: "Australia/Sydney", offset: "+11:00" },
    ].each do |timezone_info|
      it "creates dnd timings correctly for each timezone" do
        user.user_option.update(timezone: timezone_info[:timezone])

        travel_to Time.new(2020, 1, 4, 12, 0, 0, "+00:00") do
          UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(standard_schedule)

          # The default schedule is 8am - 5pm.
          # Expect DND timings to fill gaps before/after those times for 3 days.
          dnd_timings = user.do_not_disturb_timings
          offset = timezone_info[:offset]
          expect(dnd_timings[0].starts_at).to eq_time(Time.new(2020, 1, 4, 0, 0, 0, offset))
          expect(dnd_timings[0].ends_at).to eq_time(Time.new(2020, 1, 4, 7, 59, 0, offset))

          expect(dnd_timings[1].starts_at).to eq_time(Time.new(2020, 1, 4, 17, 0, 0, offset))
          expect(dnd_timings[1].ends_at).to eq_time(Time.new(2020, 1, 5, 7, 59, 0, offset))

          expect(dnd_timings[2].starts_at).to eq_time(Time.new(2020, 1, 5, 17, 0, 0, offset))
          expect(dnd_timings[2].ends_at).to eq_time(Time.new(2020, 1, 6, 7, 59, 0, offset))

          expect(dnd_timings[3].starts_at).to eq_time(Time.new(2020, 1, 6, 17, 0, 0, offset))
          expect(dnd_timings[3].ends_at).to be_within(1.second).of Time.new(
                 2020,
                 1,
                 6,
                 23,
                 59,
                 59,
                 offset,
               )
        end
      end
    end

    it "does not create duplicate record, but ensures the correct records exist" do
      user.user_option.update(timezone: "UTC")

      travel_to Time.new(2020, 1, 4, 12, 0, 0, "+00:00") do
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(standard_schedule)
        expect(user.do_not_disturb_timings.count).to eq(4)
        # All duplicates, so no new timings should be created
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(standard_schedule)
        expect(user.do_not_disturb_timings.count).to eq(4)
      end

      travel_to Time.new(2020, 1, 5, 12, 0, 0, "+00:00") do
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(standard_schedule)
        # There is 1 overlap, so expect only 3 more to be created
        expect(user.do_not_disturb_timings.count).to eq(7)
      end

      travel_to Time.new(2020, 1, 10, 12, 0, 0, "+00:00") do
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(standard_schedule)
        # There is no overlap, so expect only 4 more to be created
        expect(user.do_not_disturb_timings.count).to eq(11)
      end
    end

    it "extends previously scheduled dnd timings to remove gaps" do
      user.user_option.update(timezone: "UTC")

      travel_to Time.new(2020, 1, 4, 12, 0, 0, "+00:00") do
        existing_timing =
          user.do_not_disturb_timings.create(
            scheduled: true,
            starts_at: 1.day.ago,
            ends_at: Time.new(2020, 1, 03, 11, 0, 0, "+00:00").end_of_day,
          )
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(standard_schedule)
        expect(existing_timing.reload.ends_at).to eq_time(Time.new(2020, 1, 4, 7, 59, 0, "+00:00"))
      end
    end

    it "creates the correct timings when the whole schedule is DND (-1)" do
      user.user_option.update(timezone: "UTC")
      schedule = standard_schedule
      schedule.update(
        day_0_start_time: -1,
        day_1_start_time: -1,
        day_2_start_time: -1,
        day_3_start_time: -1,
        day_4_start_time: -1,
        day_5_start_time: -1,
        day_6_start_time: -1,
      )

      travel_to Time.new(2020, 1, 4, 12, 0, 0, "+00:00") do
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(schedule)
        expect(user.do_not_disturb_timings.count).to eq(1)
        expect(user.do_not_disturb_timings.first.starts_at).to eq_time(
          Time.new(2020, 1, 4, 0, 0, 0, "+00:00"),
        )
        expect(user.do_not_disturb_timings.first.ends_at).to be_within(1.second).of Time.new(
               2020,
               1,
               6,
               23,
               59,
               59,
               "+00:00",
             )
      end
    end

    it "creates the correct timings at the end of a month and year" do
      user.user_option.update(timezone: "UTC")
      schedule = standard_schedule
      schedule.update(
        day_3_start_time: -1, # December 31, 2020 was a thursday. testing more cases.
      )

      travel_to Time.new(2020, 12, 31, 12, 0, 0, "+00:00") do
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(schedule)
        expect(user.do_not_disturb_timings[0].starts_at).to eq_time(
          Time.new(2020, 12, 31, 0, 0, 0, "+00:00"),
        )
        expect(user.do_not_disturb_timings[0].ends_at).to eq_time(
          Time.new(2021, 1, 1, 7, 59, 0, "+00:00"),
        )
        expect(user.do_not_disturb_timings[1].starts_at).to eq_time(
          Time.new(2021, 1, 1, 17, 0, 0, "+00:00"),
        )
        expect(user.do_not_disturb_timings[1].ends_at).to eq_time(
          Time.new(2021, 1, 2, 7, 59, 0, "+00:00"),
        )
        expect(user.do_not_disturb_timings[2].starts_at).to eq_time(
          Time.new(2021, 1, 2, 17, 0, 0, "+00:00"),
        )
        expect(user.do_not_disturb_timings[2].ends_at).to be_within(1.second).of Time.new(
               2021,
               1,
               2,
               23,
               59,
               59,
               "+00:00",
             )
      end
    end

    it "handles midnight to midnight for multiple days (no timings created)" do
      user.user_option.update(timezone: "UTC")
      schedule = standard_schedule
      schedule.update(
        day_0_start_time: 0,
        day_0_end_time: 1440,
        day_1_start_time: 0,
        day_1_end_time: 1440,
        day_2_start_time: 0,
        day_2_end_time: 1440,
      )
      travel_to Time.new(2021, 1, 4, 12, 0, 0, "+00:00") do
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(schedule)
        expect(user.do_not_disturb_timings.count).to eq(0)
      end
    end

    it "publishes to message bus when the user should enter DND" do
      user.user_option.update(timezone: "UTC")
      schedule = standard_schedule
      travel_to Time.new(2020, 12, 31, 1, 0, 0, "+00:00") do
        messages =
          MessageBus.track_publish("/do-not-disturb/#{user.id}") do
            UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(schedule)
          end

        expect(messages.size).to eq(1)
        expect(messages[0].data[:ends_at]).to eq(
          Time.new(2020, 12, 31, 7, 59, 0, "+00:00").httpdate,
        )
        expect(messages[0].user_ids).to contain_exactly(user.id)
      end
    end
  end
end
