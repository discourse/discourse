# frozen_string_literal: true

class AddCacheAndDeferralMetricsToAskAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ask_ai_logs, :cache_hit, :boolean, default: false, null: false, if_not_exists: true
    add_column :ask_ai_logs, :answer_deferred_reason, :string, if_not_exists: true
    add_column :ask_ai_logs,
               :cache_evictions,
               :integer,
               default: 0,
               null: false,
               if_not_exists: true
  end
end
