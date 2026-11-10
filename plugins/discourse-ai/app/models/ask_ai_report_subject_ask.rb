# frozen_string_literal: true

class AskAiReportSubjectAsk < ActiveRecord::Base
  belongs_to :ask_ai_report_subject
  belongs_to :ask_ai_log
end

# == Schema Information
#
# Table name: ask_ai_report_subject_asks
#
#  id                       :bigint           not null, primary key
#  ask_ai_log_id            :bigint           not null
#  ask_ai_report_subject_id :bigint           not null
#
# Indexes
#
#  index_ask_ai_report_subject_asks_on_ask_ai_log_id    (ask_ai_log_id)
#  index_ask_ai_report_subject_asks_on_subject_and_log  (ask_ai_report_subject_id,ask_ai_log_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ask_ai_log_id => ask_ai_logs.id) ON DELETE => cascade
#  fk_rails_...  (ask_ai_report_subject_id => ask_ai_report_subjects.id) ON DELETE => cascade
#
