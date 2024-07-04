# frozen_string_literal: true

class UserNotificationScheduleSerializer < ApplicationSerializer
  attributes :id, :user_id, :enabled

  7.times do |n|
    attribute :"day_#{n}_start_time"
    attribute :"day_#{n}_end_time"
  end
end
