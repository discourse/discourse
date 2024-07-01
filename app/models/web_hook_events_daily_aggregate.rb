# frozen_string_literal: true

class WebHookEventsDailyAggregate < ActiveRecord::Base
  belongs_to :web_hook

  default_scope { order("created_at DESC") }
  before_create :aggregate!

  def self.purge_old
    where("created_at < ?", SiteSetting.retain_web_hook_events_aggregate_days.days.ago).delete_all
  end

  def self.by_day(start_date, end_date, web_hook_id = nil)
    result = where("date >= ? AND date <= ?", start_date.to_date, end_date.to_date)
    result = result.where(web_hook_id: web_hook_id) if web_hook_id
    result
  end

  def aggregate!
    events =
      WebHookEvent.where(
        "created_at >= ? AND created_at < ? AND web_hook_id = ?",
        self.date,
        self.date + 1.day,
        self.web_hook_id,
      )

    if events.empty?
      self.mean_duration = 0
      self.successful_event_count = 0
      self.failed_event_count = 0
      return
    end

    self.mean_duration = events.sum(:duration) / events.count
    self.successful_event_count = events.where("status >= 200 AND status <= 299").count
    self.failed_event_count = events.where("status < 200 OR status > 299").count
  end
end

# == Schema Information
#
# Table name: web_hook_events_daily_aggregates
#
#  id                     :bigint           not null, primary key
#  web_hook_id            :bigint           not null
#  date                   :date
#  successful_event_count :integer
#  failed_event_count     :integer
#  mean_duration          :integer          default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_web_hook_events_daily_aggregates_on_web_hook_id  (web_hook_id)
#
