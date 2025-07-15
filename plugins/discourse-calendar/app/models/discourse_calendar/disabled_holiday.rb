# frozen_string_literal: true

module DiscourseCalendar
  class DisabledHoliday < ActiveRecord::Base
    validates :holiday_name, presence: true
    validates :region_code, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_calendar_disabled_holidays
#
#  id           :bigint           not null, primary key
#  holiday_name :string           not null
#  region_code  :string           not null
#  disabled     :boolean          default(TRUE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_disabled_holidays_on_holiday_name_and_region_code  (holiday_name,region_code)
#
