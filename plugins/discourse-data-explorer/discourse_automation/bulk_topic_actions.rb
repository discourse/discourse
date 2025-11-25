# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("data_explorer_bulk_topic_actions") do
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
                id: "add_tags",
                name:
                  "js.discourse_automation.scriptables.data_explorer_bulk_topic_actions.action.add_tags",
              },
              {
                id: "remove_tags",
                name:
                  "js.discourse_automation.scriptables.data_explorer_bulk_topic_actions.action.remove_tags",
              },
              {
                id: "close_topic",
                name:
                  "js.discourse_automation.scriptables.data_explorer_bulk_topic_actions.action.close_topic",
              },
            ],
          }
    field :tags, component: :tags, required: false

    version 1
    triggerables %i[recurring point_in_time]
    run_in_background

    script do |_context, fields, automation|
      query_id = fields.dig("query_id", "value")
      query_params = fields.dig("query_params", "value") || {}
      action = fields.dig("action", "value")
      tags = fields.dig("tags", "value") || []

      unless SiteSetting.data_explorer_enabled
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - plugin must be enabled to run automation #{automation.id}"
        next
      end

      unless SiteSetting.data_explorer_bulk_actions_enabled
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - bulk actions must be enabled to run automation #{automation.id}"
        next
      end

      # Validate tags are provided for tag actions
      if %w[add_tags remove_tags].include?(action) && tags.blank?
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - tags field is required for action '#{action}' in automation #{automation.id}"
        next
      end

      query = DiscourseDataExplorer::Query.find_by(id: query_id)
      if query.blank?
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't find query ID (#{query_id}) for automation #{automation.id}"
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
      topic_id_index = cols.index("topic_id")

      unless topic_id_index
        Rails.logger.error "#{DiscourseDataExplorer::PLUGIN_NAME} - query must include 'topic_id' column for topic actions in automation #{automation.id}"
        next
      end

      rows = pg_result.values
      total_rows = rows.length
      success_count = 0
      error_count = 0
      errors = []

      rows.each_with_index do |row, idx|
        topic_id = row[topic_id_index]

        begin
          topic = Topic.find_by(id: topic_id)
          unless topic
            error_count += 1
            errors << { row: idx, topic_id: topic_id, error: "Topic not found" }
            next
          end

          case action
          when "add_tags"
            existing_tags = topic.tags.pluck(:name)
            new_tags = (existing_tags + tags).uniq
            DiscourseTagging.tag_topic_by_names(
              topic,
              Guardian.new(Discourse.system_user),
              new_tags,
            )
            success_count += 1
          when "remove_tags"
            existing_tags = topic.tags.pluck(:name)
            remaining_tags = existing_tags - tags
            DiscourseTagging.tag_topic_by_names(
              topic,
              Guardian.new(Discourse.system_user),
              remaining_tags,
            )
            success_count += 1
          when "close_topic"
            if topic.closed?
              success_count += 1 # Already closed, idempotent
            else
              topic.update_status("closed", true, Discourse.system_user)
              success_count += 1
            end
          end
        rescue => e
          error_count += 1
          errors << { row: idx, topic_id: topic_id, error: e.message }
          Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - failed to process topic #{topic_id} in automation #{automation.id}: #{e.message}"

          # Stop if too many errors
          break if error_count > total_rows * 0.1
        end
      end

      # Log execution
      DiscourseDataExplorer::BulkActionLog.log_execution(
        query_id: query_id,
        automation_id: automation.id,
        action_type: "topic_#{action}",
        total_rows: total_rows,
        success_count: success_count,
        error_count: error_count,
        errors_detail: errors.take(100), # Limit stored errors
      )

      if error_count > 0
        Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - automation #{automation.id} completed with #{success_count} successes and #{error_count} errors"
      else
        Rails.logger.info "#{DiscourseDataExplorer::PLUGIN_NAME} - automation #{automation.id} completed successfully: #{success_count} topics processed"
      end
    end
  end
end
