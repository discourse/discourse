# frozen_string_literal: true

class UserNotificationSchedule < ActiveRecord::Base
  belongs_to :user

  DEFAULT = -> do
    attrs = { enabled: false }
    7.times do |n|
      attrs["day_#{n}_start_time".to_sym] = 480
      attrs["day_#{n}_end_time".to_sym] = 1020
    end
    attrs
  end.call

  validate :has_valid_times
  validates :enabled, inclusion: { in: [true, false] }

  scope :enabled, -> { where(enabled: true) }

  def create_do_not_disturb_timings(delete_existing: false)
    destroy_scheduled_timings if delete_existing
    UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(self)
  end

  def destroy_scheduled_timings
    user.do_not_disturb_timings.where(scheduled: true).destroy_all
  end

  private

  def has_valid_times
    7.times do |n|
      start_key = "day_#{n}_start_time"
      end_key = "day_#{n}_end_time"

      if self[start_key].nil? || self[start_key] > 1410 || self[start_key] < -1
        errors.add(start_key, "is invalid")
      end

      errors.add(end_key, "is invalid") if self[end_key].nil? || self[end_key] > 1440

      if self[start_key] && self[end_key] && self[start_key] > self[end_key]
        errors.add(start_key, "is after end time")
      end
    end
  end
end

# == Schema Information
#
# Table name: user_notification_schedules
#
#  id               :bigint           not null, primary key
#  user_id          :integer          not null
#  enabled          :boolean          default(FALSE), not null
#  day_0_start_time :integer          not null
#  day_0_end_time   :integer          not null
#  day_1_start_time :integer          not null
#  day_1_end_time   :integer          not null
#  day_2_start_time :integer          not null
#  day_2_end_time   :integer          not null
#  day_3_start_time :integer          not null
#  day_3_end_time   :integer          not null
#  day_4_start_time :integer          not null
#  day_4_end_time   :integer          not null
#  day_5_start_time :integer          not null
#  day_5_end_time   :integer          not null
#  day_6_start_time :integer          not null
#  day_6_end_time   :integer          not null
#
# Indexes
#
#  index_user_notification_schedules_on_enabled  (enabled)
#  index_user_notification_schedules_on_user_id  (user_id)
#
