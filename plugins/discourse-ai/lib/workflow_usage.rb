# frozen_string_literal: true

module DiscourseAi
  class WorkflowUsage
    WORKFLOW_ID_PATTERN = /\A[1-9]\d{0,17}\z/

    def self.workflow_id(log)
      id =
        if log.has_attribute?(:workflow_id)
          log[:workflow_id].to_s
        else
          log.feature_context&.fetch("workflow_id", nil).to_s
        end
      id.to_i if log.feature_name == "workflow" && id.match?(WORKFLOW_ID_PATTERN)
    end

    def self.workflows_for(logs)
      return {} if !defined?(DiscourseWorkflows::Workflow)

      ids = logs.filter_map { |log| workflow_id(log) }.uniq
      DiscourseWorkflows::Workflow.where(id: ids).pluck(:id, :name).to_h
    end

    def self.breakdown(start_date:, end_date:, feature: nil, model: nil)
      return [] if feature.present? && feature != "workflow"
      return [] if !defined?(DiscourseWorkflows::Workflow)

      logs = AiApiAuditLog.where(feature_name: "workflow", created_at: start_date..end_date)
      if model.present?
        if model.to_s.match?(Completions::Report::LLM_MODEL_ID_PATTERN)
          llm = LlmModel.find_by(id: model)
          logs =
            if llm
              logs.where("llm_id = ? OR (llm_id IS NULL AND language_model = ?)", llm.id, llm.name)
            else
              logs.where(llm_id: model)
            end
        else
          logs = logs.where(language_model: model)
        end
      end

      rows =
        logs
          .joins("LEFT JOIN llm_models ON llm_models.id = ai_api_audit_logs.llm_id")
          .where("feature_context ->> 'workflow_id' ~ ?", "^[1-9][0-9]{0,17}$")
          .group("feature_context ->> 'workflow_id'")
          .order(Arel.sql("COUNT(*) DESC"))
          .pluck(
            Arel.sql("feature_context ->> 'workflow_id'"),
            Arel.sql("COUNT(*)"),
            Arel.sql(
              "COALESCE(SUM(request_tokens), 0) + COALESCE(SUM(response_tokens), 0) + " \
                "COALESCE(SUM(cache_read_tokens), 0) + COALESCE(SUM(cache_write_tokens), 0)",
            ),
            Arel.sql(
              "COALESCE(SUM(#{LlmModel.estimated_or_calculated_spending_sql(:ai_api_audit_logs)}), 0)",
            ),
          )

      names =
        DiscourseWorkflows::Workflow
          .where(id: rows.map { |row| row[0].to_i })
          .pluck(:id, :name)
          .to_h
      rows.filter_map do |id, requests, tokens, cost|
        next if !names.key?(id.to_i)

        {
          id: id.to_i,
          name: names.fetch(id.to_i),
          requests: requests,
          tokens: tokens,
          estimated_cost: cost.to_f,
        }
      end
    end

    def self.for(workflow_id:, since:)
      count, tokens, estimated_cost =
        AiApiAuditLog
          .where(feature_name: "workflow", created_at: since..)
          .where("feature_context ->> 'workflow_id' = ?", workflow_id.to_s)
          .pick(
            Arel.sql("COUNT(*)"),
            Arel.sql(
              "COALESCE(SUM(request_tokens), 0) + COALESCE(SUM(response_tokens), 0) + " \
                "COALESCE(SUM(cache_read_tokens), 0) + COALESCE(SUM(cache_write_tokens), 0)",
            ),
            Arel.sql("COALESCE(SUM(estimated_cost), 0)"),
          )

      { requests: count, tokens: tokens, estimated_cost: estimated_cost.to_f }
    end
  end
end
