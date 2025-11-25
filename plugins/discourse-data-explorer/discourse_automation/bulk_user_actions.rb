# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("data_explorer_bulk_user_actions") do
    queries =
      DiscourseDataExplorer::Query
        .where(hidden: false)
        .map { |q| { id: q.id, translated_name: q.name } }

    field :query_id, component: :choices, required: true, extra: { content: queries }
    field :query_params, component: :"key-value", accepts_placeholders: true
    field :action,
          component: :choices,
          required: true,
          extra: {
            content: [
              {
                id: "add_to_group",
                name:
                  "js.discourse_automation.scriptables.data_explorer_bulk_user_actions.action.add_to_group",
              },
              {
                id: "remove_from_group",
                name:
                  "js.discourse_automation.scriptables.data_explorer_bulk_user_actions.action.remove_from_group",
              },
            ],
          }
    field :target_group, component: :group, required: true

    version 1
    triggerables %i[recurring point_in_time]
    run_in_background

    script do |_context, fields, automation|
      query_id = fields.dig("query_id", "value")
      query_params = fields.dig("query_params", "value") || {}
      action = fields.dig("action", "value")
      target_group_id = fields.dig("target_group", "value")

      unless SiteSetting.data_explorer_enabled
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - plugin must be enabled to run automation #{automation.id}"
        next
      end

      unless SiteSetting.data_explorer_bulk_actions_enabled
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - bulk actions must be enabled to run automation #{automation.id}"
        next
      end

      query = DiscourseDataExplorer::Query.find_by(id: query_id)
      if query.blank?
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't find query ID (#{query_id}) for automation #{automation.id}"
        next
      end

      target_group = Group.find_by(id: target_group_id)
      if target_group.blank?
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't find target group ID (#{target_group_id}) for automation #{automation.id}"
        next
      end

      # Execute query
      begin
        result = DiscourseDataExplorer::DataExplorer.run_query(query, query_params)
      rescue => e
        Rails.logger.error "#{DiscourseDataExplorer::PLUGIN_NAME} - query execution failed for automation #{automation.id}: #{e.message}"
        next
      end

      if result[:error]
        Rails.logger.error "#{DiscourseDataExplorer::PLUGIN_NAME} - query returned error for automation #{automation.id}: #{result[:error]}"
        next
      end

      pg_result = result[:pg_result]
      cols = pg_result.fields
      user_id_index = cols.index("user_id")

      unless user_id_index
        Rails.logger.error "#{DiscourseDataExplorer::PLUGIN_NAME} - query must include 'user_id' column for user actions in automation #{automation.id}"
        next
      end

      rows = pg_result.values
      total_rows = rows.length
      success_count = 0
      error_count = 0
      errors = []

      rows.each_with_index do |row, idx|
        user_id = row[user_id_index]

        begin
          user = User.find_by(id: user_id)
          unless user
            error_count += 1
            errors << { row: idx, user_id: user_id, error: "User not found" }
            next
          end

          case action
          when "add_to_group"
            if target_group.add(user)
              success_count += 1
            else
              # User was already in group (idempotent)
              success_count += 1
            end
          when "remove_from_group"
            if target_group.remove(user)
              success_count += 1
            else
              # User wasn't in group (idempotent)
              success_count += 1
            end
          end
        rescue => e
          error_count += 1
          errors << { row: idx, user_id: user_id, error: e.message }
          Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - failed to process user #{user_id} in automation #{automation.id}: #{e.message}"

          # Stop if too many errors
          break if error_count > total_rows * 0.1
        end
      end

      # Log execution
      DiscourseDataExplorer::BulkActionLog.log_execution(
        query_id: query_id,
        automation_id: automation.id,
        action_type: "user_#{action}",
        total_rows: total_rows,
        success_count: success_count,
        error_count: error_count,
        errors_detail: errors.take(100), # Limit stored errors
      )

      if error_count > 0
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - automation #{automation.id} completed with #{success_count} successes and #{error_count} errors"
      else
        Rails.logger.info "#{DiscourseDataExplorer::PLUGIN_NAME} - automation #{automation.id} completed successfully: #{success_count} users processed"
      end
    end
  end
end
