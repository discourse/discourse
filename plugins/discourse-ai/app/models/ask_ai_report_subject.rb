# frozen_string_literal: true

class AskAiReportSubject < ActiveRecord::Base
  belongs_to :ask_ai_report
  has_many :ask_ai_report_subject_asks, dependent: :delete_all
  has_many :ask_ai_logs, through: :ask_ai_report_subject_asks
end

# == Schema Information
#
# Table name: ask_ai_report_subjects
#
#  id               :bigint           not null, primary key
#  ask_count        :integer          not null
#  description      :text             not null
#  name             :string           not null
#  position         :integer          not null
#  ask_ai_report_id :bigint           not null
#
# Indexes
#
#  index_ask_ai_report_subjects_on_ask_ai_report_id_and_position  (ask_ai_report_id,position) UNIQUE
#
