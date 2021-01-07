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
end
