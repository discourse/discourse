# frozen_string_literal: true

class UserNotificationScheduleSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :enabled,
             :day_0_start_time,
             :day_0_end_time,
             :day_1_start_time,
             :day_1_end_time,
             :day_2_start_time,
             :day_2_end_time,
             :day_3_start_time,
             :day_3_end_time,
             :day_4_start_time,
             :day_4_end_time,
             :day_5_start_time,
             :day_5_end_time,
             :day_6_start_time,
             :day_6_end_time
end
