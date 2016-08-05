class SchedulerStat < ActiveRecord::Base
  def self.purge_old
    where('started_at < ?', 3.months.ago).delete_all
  end
end

# == Schema Information
#
# Table name: scheduler_stats
#
#  id                :integer          not null, primary key
#  name              :string           not null
#  hostname          :string           not null
#  pid               :integer          not null
#  duration_ms       :integer
#  live_slots_start  :integer
#  live_slots_finish :integer
#  started_at        :datetime         not null
#  success           :boolean
#
