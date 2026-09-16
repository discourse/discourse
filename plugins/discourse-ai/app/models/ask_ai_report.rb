# frozen_string_literal: true

class AskAiReport < ActiveRecord::Base
  belongs_to :requested_by, class_name: "User"
  belongs_to :topic, optional: true
  has_many :subjects, -> { order(:position) }, class_name: "AskAiReportSubject", dependent: :destroy

  enum :report_status, { queued: 0, running: 1, completed: 2, failed: 3 }, prefix: true

  def self.expire_stale!
    where(report_status: %i[queued running]).where("updated_at < ?", 30.minutes.ago).update_all(
      report_status: report_statuses[:failed],
      updated_at: Time.current,
    )
  end

  def selected_logs
    AskAiLog.where(id: selected_ask_ids).order(id: :desc)
  end
end

# == Schema Information
#
# Table name: ask_ai_reports
#
#  id                 :bigint           not null, primary key
#  end_date           :date             not null
#  report_status      :integer          default("queued"), not null
#  reported_ask_count :integer          not null
#  selected_ask_ids   :bigint           default([]), not null, is an Array
#  send_to_groups     :boolean          default(FALSE), not null
#  start_date         :date             not null
#  summary            :text             default(""), not null
#  total_ask_count    :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  requested_by_id    :bigint           not null
#  topic_id           :bigint
#
# Indexes
#
#  index_ask_ai_reports_on_created_at                              (created_at)
#  index_ask_ai_reports_on_start_date_and_end_date_and_created_at  (start_date,end_date,created_at)
#
