# frozen_string_literal: true

class AskAiLog < ActiveRecord::Base
  belongs_to :user

  enum :ask_outcome, { answered: 0, no_answer: 1, failed: 2, cancelled: 3 }, prefix: true
  enum :failure_stage, { rewrite: 0, retrieval: 1, synthesis: 2 }, prefix: true
end

# == Schema Information
#
# Table name: ask_ai_logs
#
#  id                      :bigint           not null, primary key
#  answer                  :text
#  answer_title            :text
#  ask_outcome             :integer
#  asked_at                :datetime         not null
#  candidate_post_ids      :bigint           default([]), not null, is an Array
#  failure_stage           :integer
#  keyword_query           :text
#  query                   :text             not null
#  query_locale            :string
#  semantic_query          :text
#  source_post_ids         :bigint           default([]), not null, is an Array
#  suggested_follow_up     :text
#  time_to_first_answer_ms :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null
#
# Indexes
#
#  index_ask_ai_logs_on_asked_at              (asked_at)
#  index_ask_ai_logs_on_user_id_and_asked_at  (user_id,asked_at)
#
