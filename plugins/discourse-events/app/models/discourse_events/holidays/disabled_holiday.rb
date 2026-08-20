# frozen_string_literal: true

module DiscourseEvents
  module Holidays
    class DisabledHoliday < ActiveRecord::Base
      # Pinned: the engine's `isolate_namespace` would otherwise derive
      # "discourse_events_disabled_holidays" from the namespace.
      self.table_name = "discourse_calendar_disabled_holidays"

      validates :holiday_name, presence: true
      validates :region_code, presence: true
    end
  end
end

# == Schema Information
#
# Table name: discourse_calendar_disabled_holidays
#
#  id           :bigint           not null, primary key
#  disabled     :boolean          default(TRUE), not null
#  holiday_name :string           not null
#  region_code  :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_disabled_holidays_on_holiday_name_and_region_code  (holiday_name,region_code)
#
