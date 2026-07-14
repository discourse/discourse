# frozen_string_literal: true
class AiSpamLog < ActiveRecord::Base
  belongs_to :post
  belongs_to :llm_model
  belongs_to :ai_api_audit_log
  belongs_to :reviewable
end

# == Schema Information
#
# Table name: ai_spam_logs
#
#  id                  :bigint           not null, primary key
#  error               :string(3000)
#  is_spam             :boolean          not null
#  payload             :string(20000)    default(""), not null
#  reason              :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ai_api_audit_log_id :bigint
#  llm_model_id        :bigint           not null
#  post_id             :bigint           not null
#  reviewable_id       :bigint
#
# Indexes
#
#  index_ai_spam_logs_on_post_id  (post_id)
#
