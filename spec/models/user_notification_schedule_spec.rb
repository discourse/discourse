# frozen_string_literal: true

RSpec.describe UserNotificationSchedule do
  fab!(:user) { Fabricate(:user) }

  describe "validations" do
    it "is invalid when no times are specified" do
      schedule = UserNotificationSchedule.create({ user: user, enabled: true })
      expect(schedule.errors.attribute_names).to eq(
        %i[
          day_0_start_time
          day_0_end_time
          day_1_start_time
          day_1_end_time
          day_2_start_time
          day_2_end_time
          day_3_start_time
          day_3_end_time
          day_4_start_time
          day_4_end_time
          day_5_start_time
          day_5_end_time
          day_6_start_time
          day_6_end_time
        ],
      )
    end

    it "is invalid when a start time is below -1" do
      schedule =
        UserNotificationSchedule.new({ user: user }.merge(UserNotificationSchedule::DEFAULT))
      schedule.day_0_start_time = -2
      schedule.save
      expect(schedule.errors.count).to eq(1)
      expect(schedule.errors[:day_0_start_time]).to be_present
    end

    it "invalid when an end time is greater than 1440" do
      schedule =
        UserNotificationSchedule.new({ user: user }.merge(UserNotificationSchedule::DEFAULT))
      schedule.day_0_end_time = 1441
      schedule.save
      expect(schedule.errors.count).to eq(1)
      expect(schedule.errors[:day_0_end_time]).to be_present
    end

    it "invalid when the start time is greater than the end time" do
      schedule =
        UserNotificationSchedule.new({ user: user }.merge(UserNotificationSchedule::DEFAULT))
      schedule.day_0_start_time = 1000
      schedule.day_0_end_time = 800
      schedule.save
      expect(schedule.errors.count).to eq(1)
      expect(schedule.errors[:day_0_start_time]).to be_present
    end
  end
end
