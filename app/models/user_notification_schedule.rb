# frozen_string_literal: true

class UserNotificationSchedule < ActiveRecord::Base
  belongs_to :user
end
