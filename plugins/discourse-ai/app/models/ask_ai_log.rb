# frozen_string_literal: true

class AskAiLog < ActiveRecord::Base
  belongs_to :user

  def self.for_reports
    group_ids = SiteSetting.ai_ask_ai_report_exclude_groups_map
    return all if group_ids.empty?

    where.not(user_id: GroupUser.where(group_id: group_ids).select(:user_id))
  end

  # The search's scope and the decision model's verdicts, kept beside the
  # heuristic's guess so the two can be compared.
  def record_judgement!(scope:, judgement:)
    update!(
      ask_scope: scope.to_s,
      ask_intent_model: judgement&.intent.to_s,
      ask_intent_probability: judgement&.probability || 0,
      ask_scope_model: judgement&.scope.to_s,
      ask_scope_probability: judgement&.scope_probability || 0,
    )
  end

  enum :ask_outcome, { answered: 0, no_answer: 1, failed: 2, cancelled: 3 }, prefix: true
  enum :failure_stage, { rewrite: 0, retrieval: 1, synthesis: 2 }, prefix: true
end

# == Schema Information
#
# Table name: ask_ai_logs
#
#  id                        :bigint           not null, primary key
#  answer                    :text
#  answer_title              :text
#  ask_intent_heuristic      :string           default(""), not null
#  ask_intent_model          :string           default(""), not null
#  ask_intent_probability    :float            default(0.0), not null
#  ask_outcome               :integer
#  ask_scope                 :string           default(""), not null
#  ask_scope_model           :string           default(""), not null
#  ask_scope_probability     :float            default(0.0), not null
#  ask_tab_opened            :string           default(""), not null
#  ask_tab_opened_reason     :string           default(""), not null
#  ask_tab_switched_after_ms :integer          default(0), not null
#  ask_tab_switched_to       :string           default(""), not null
#  ask_trigger               :string           default(""), not null
#  ask_trigger_reason        :string           default(""), not null
#  asked_at                  :datetime         not null
#  candidate_post_ids        :bigint           default([]), not null, is an Array
#  failure_stage             :integer
#  keyword_query             :text
#  query                     :text             not null
#  query_locale              :string
#  semantic_query            :text
#  source_post_ids           :bigint           default([]), not null, is an Array
#  suggested_follow_up       :text
#  time_to_first_answer_ms   :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_ask_ai_logs_on_asked_at              (asked_at)
#  index_ask_ai_logs_on_user_id_and_asked_at  (user_id,asked_at)
#
