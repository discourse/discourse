# frozen_string_literal: true

class UserNotificationSchedule < ActiveRecord::Base
  belongs_to :user

  DEFAULT = {
    enabled: false,
    day_0_start_time: 480,
    day_0_end_time: 1020,
    day_1_start_time: 480,
    day_1_end_time: 1020,
    day_2_start_time: 480,
    day_2_end_time: 1020,
    day_3_start_time: 480,
    day_3_end_time: 1020,
    day_4_start_time: 480,
    day_4_end_time: 1020,
    day_5_start_time: 480,
    day_5_end_time: 1020,
    day_6_start_time: 480,
    day_6_end_time: 1020
  }

  validate :has_valid_times
  validates :enabled, inclusion: { in: [ true, false ] }

  scope :enabled, -> { where(enabled: true) }

  def create_do_not_disturb_timings(delete_existing: false)
    user.do_not_disturb_timings.where(scheduled: true).destroy_all if delete_existing
    UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(self)
  end

  private

  def has_valid_times
    7.times do |n|
      start_key = "day_#{n}_start_time"
      end_key = "day_#{n}_end_time"

      if self[start_key].nil? || self[start_key] > 1410 || self[start_key] < -1
        errors.add(start_key, "is invalid")
      end

      if self[end_key].nil? || self[end_key] > 1440
        errors.add(end_key, "is invalid")
      end

      if self[start_key] && self[end_key] && self[start_key] > self[end_key]
        errors.add(start_key, "is after end time")
      end
    end
  end
end
