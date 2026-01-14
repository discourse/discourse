# frozen_string_literal: true

class BackfillAiApiRequestStats < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    return unless table_exists?(:ai_api_audit_logs)
    return unless table_exists?(:ai_api_request_stats)

    # Default to 7 days if SiteSetting is not available or configured
    rollup_days = 7
    begin
      rollup_days = SiteSetting.ai_usage_rollup_after_days if defined?(SiteSetting)
    rescue StandardError
      # Keep default
    end

    cutoff = rollup_days.days.ago.beginning_of_day

    puts "Backfilling AI API Request Stats..."
    puts "Cutoff for rollup: #{cutoff}"

    # 1. Backfill rolled up stats (older than cutoff)
    # Process day by day to avoid massive transactions/locks

    min_created_at = connection.select_value("SELECT MIN(created_at) FROM ai_api_audit_logs")
    if min_created_at
      current_date = min_created_at.to_date
      end_date = cutoff.to_date

      while current_date < end_date
        puts "Processing rollup for #{current_date}"

        execute <<~SQL
          INSERT INTO ai_api_request_stats (
            bucket_date, user_id, provider_id, llm_id, language_model, feature_name,
            request_tokens, response_tokens, cache_read_tokens, cache_write_tokens, usage_count,
            rolled_up, created_at, updated_at
          )
          SELECT
            date_trunc('day', created_at),
            user_id,
            provider_id,
            llm_id,
            language_model,
            feature_name,
            SUM(COALESCE(request_tokens, 0)),
            SUM(COALESCE(response_tokens, 0)),
            SUM(COALESCE(cache_read_tokens, 0)),
            SUM(COALESCE(cache_write_tokens, 0)),
            COUNT(*),
            true,
            date_trunc('day', created_at),
            NOW()
          FROM ai_api_audit_logs
          WHERE created_at >= '#{current_date}'::timestamp 
            AND created_at < '#{current_date + 1.day}'::timestamp
          GROUP BY date_trunc('day', created_at), user_id, provider_id, llm_id, language_model, feature_name
        SQL

        current_date += 1.day
      end
    end

    # 2. Backfill recent stats (newer than cutoff)
    # Process in batches by ID

    batch_size = 2000
    max_id =
      connection.select_value(
        "SELECT MAX(id) FROM ai_api_audit_logs WHERE created_at >= '#{cutoff}'::timestamp",
      )

    if max_id
      min_id =
        connection.select_value(
          "SELECT MIN(id) FROM ai_api_audit_logs WHERE created_at >= '#{cutoff}'::timestamp",
        )
      current_id = min_id

      while current_id <= max_id
        puts "Processing recent stats batch starting at #{current_id}"

        execute <<~SQL
          INSERT INTO ai_api_request_stats (
            bucket_date, user_id, provider_id, llm_id, language_model, feature_name,
            request_tokens, response_tokens, cache_read_tokens, cache_write_tokens, usage_count,
            rolled_up, created_at, updated_at
          )
          SELECT
            created_at,
            user_id,
            provider_id,
            llm_id,
            language_model,
            feature_name,
            COALESCE(request_tokens, 0),
            COALESCE(response_tokens, 0),
            COALESCE(cache_read_tokens, 0),
            COALESCE(cache_write_tokens, 0),
            1,
            false,
            created_at,
            NOW()
          FROM ai_api_audit_logs
          WHERE id >= #{current_id} AND id < #{current_id + batch_size}
            AND created_at >= '#{cutoff}'::timestamp
        SQL

        current_id += batch_size
        sleep 0.01
      end
    end
  end

  def down
    execute "TRUNCATE TABLE ai_api_request_stats"
  end
end
