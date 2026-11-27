# frozen_string_literal: true

# name: discourse-data-explorer
# about: Allows you to make SQL queries against your live database, allowing for up-to-the-minute stats reporting.
# meta_topic_id: 32566
# version: 0.3
# authors: Riking
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-data-explorer

enabled_site_setting :data_explorer_enabled

register_asset "stylesheets/explorer.scss"

register_svg_icon "angle-down"
register_svg_icon "angle-right"
register_svg_icon "chart-line"
register_svg_icon "angle-left"
register_svg_icon "circle-exclamation"
register_svg_icon "info"
register_svg_icon "pencil"
register_svg_icon "thumbtack-slash"
register_svg_icon "upload"

add_admin_route "explorer.title", "discourse-data-explorer", use_new_show_route: true

module ::DiscourseDataExplorer
  PLUGIN_NAME = "discourse-data-explorer"

  # This should always match the max value for the
  # data_explorer_query_result_limit site setting
  QUERY_RESULT_MAX_LIMIT = 10_000
end

require_relative "lib/discourse_data_explorer/engine"

after_initialize do
  register_seedfu_fixtures(Rails.root.join("plugins/discourse-data-explorer/db/fixtures"))

  require_relative "lib/discourse_data_explorer/mcp_tools"

  register_mcp_tool(
    "discourse_get_query",
    title: "Get Data Explorer query",
    description:
      "Returns the definition of a saved Data Explorer query. Requires an admin account.",
    implementation: DiscourseDataExplorer::McpTools::GetQuery,
    input_schema: {
      type: "object",
      properties: {
        id: {
          type: "integer",
          minimum: 1,
        },
      },
      required: ["id"],
      additionalProperties: false,
    },
    output_schema: DiscourseDataExplorer::McpTools::GetQuery::OUTPUT_SCHEMA,
    required_scopes: DiscourseDataExplorer::McpTools::GetQuery::REQUIRED_SCOPES,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
    risk: :administration,
    availability: -> { SiteSetting.data_explorer_enabled },
  )

  register_mcp_tool(
    "discourse_run_query",
    title: "Run Data Explorer query",
    description: "Runs a saved Data Explorer query that the authenticated user can access.",
    implementation: DiscourseDataExplorer::McpTools::RunQuery,
    input_schema: {
      type: "object",
      properties: {
        id: {
          type: "integer",
        },
        params: {
          type: "object",
        },
        limit: {
          anyOf: [
            { type: "integer", minimum: 1, maximum: DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT },
            { const: "ALL" },
          ],
        },
        explain: {
          type: "boolean",
          default: false,
        },
      },
      required: ["id"],
      additionalProperties: false,
    },
    output_schema: DiscourseDataExplorer::McpTools::RunQuery::OUTPUT_SCHEMA,
    required_scopes: DiscourseDataExplorer::McpTools::RunQuery::REQUIRED_SCOPES,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
    availability: -> { SiteSetting.data_explorer_enabled },
  )

  query_properties = {
    name: {
      type: "string",
      minLength: 1,
      maxLength: 255,
      pattern: "\\S",
    },
    sql: {
      type: "string",
      minLength: 1,
      maxLength: 100_000,
      pattern: "\\S",
    },
    description: {
      type: "string",
      maxLength: 10_000,
    },
    group_ids: {
      type: "array",
      maxItems: 100,
      uniqueItems: true,
      items: {
        type: "integer",
        minimum: 0,
      },
    },
    confirm_save: {
      const: true,
    },
  }
  {
    "discourse_create_query" => {
      title: "Create Data Explorer query",
      description:
        "Saves a query without running its SQL. Group access allows members to run the query and read its results. Requires an admin account and explicit confirmation.",
      implementation: DiscourseDataExplorer::McpTools::CreateQuery,
      properties: query_properties,
      required: %w[name sql confirm_save],
      destructive: false,
      idempotent: false,
    },
    "discourse_update_query" => {
      title: "Update Data Explorer query",
      description:
        "Updates only supplied fields without running SQL. Group access allows members to read query results; an empty group_ids array removes group access. Requires an admin account and explicit confirmation.",
      implementation: DiscourseDataExplorer::McpTools::UpdateQuery,
      properties: query_properties.merge(id: { type: "integer", minimum: 1 }),
      required: %w[id confirm_save],
      destructive: true,
      idempotent: true,
    },
    "discourse_delete_query" => {
      title: "Delete Data Explorer query",
      description:
        "Hides a saved query and removes it from the admin dashboard. Requires an admin account and explicit confirmation.",
      implementation: DiscourseDataExplorer::McpTools::DeleteQuery,
      properties: {
        id: {
          type: "integer",
          minimum: 1,
        },
        confirm_delete: {
          const: true,
        },
      },
      required: %w[id confirm_delete],
      destructive: true,
      idempotent: false,
    },
  }.each do |identifier, config|
    implementation = config.fetch(:implementation)
    register_mcp_tool(
      identifier,
      title: config.fetch(:title),
      description: config.fetch(:description),
      implementation:,
      input_schema: {
        type: "object",
        properties: config.fetch(:properties),
        required: config.fetch(:required),
        additionalProperties: false,
      },
      output_schema: implementation::OUTPUT_SCHEMA,
      required_scopes: implementation::REQUIRED_SCOPES,
      annotations: {
        readOnlyHint: false,
        destructiveHint: config.fetch(:destructive),
        idempotentHint: config.fetch(:idempotent),
        openWorldHint: false,
      },
      risk: :administration,
      availability: -> { SiteSetting.data_explorer_enabled },
    )
  end

  GlobalSetting.add_default(:max_data_explorer_api_reqs_per_10_seconds, 2)

  # Available options:
  #   - warn
  #   - warn+block
  #   - block
  GlobalSetting.add_default(:max_data_explorer_api_req_mode, "warn")

  if respond_to?(:register_discourse_workflows_node)
    register_svg_icon "database"
    register_discourse_workflows_node do
      require_relative "lib/discourse_data_explorer/workflows/sql_action/v1"
      DiscourseDataExplorer::Workflows::SqlAction::V1
    end
  end

  add_to_class(:guardian, :user_is_a_member_of_group?) do |group|
    return false if !current_user
    return true if current_user.admin?
    current_user.group_ids.include?(group.id)
  end

  add_to_class(:guardian, :user_can_access_query?) do |query|
    return false if !current_user
    return true if current_user.admin?
    query.groups.any? { |group| user_is_a_member_of_group?(group) }
  end

  add_to_class(:guardian, :group_and_user_can_access_query?) do |group, query|
    return false if !current_user
    return true if current_user.admin?
    user_is_a_member_of_group?(group) && query.groups.exists?(id: group.id)
  end

  add_to_serializer(
    :group_show,
    :has_visible_data_explorer_queries,
    include_condition: -> { scope.user_is_a_member_of_group?(object) },
  ) { DiscourseDataExplorer::Query.for_group(object).exists? }

  register_bookmarkable(DiscourseDataExplorer::QueryGroupBookmarkable)

  register_admin_dashboard_report_source(DiscourseDataExplorer::AdminDashboardReportProvider)

  add_api_key_scope(
    :data_explorer,
    {
      run_queries: {
        actions: %w[discourse_data_explorer/query#run discourse_data_explorer/query#public_run],
        path_params: %i[id],
      },
    },
  )

  reloadable_patch do
    if defined?(DiscourseAutomation)
      add_automation_scriptable("recurring_data_explorer_result_pm") do
        queries =
          DiscourseDataExplorer::Query
            .where(hidden: false)
            .map { |q| { id: q.id, translated_name: q.name } }
        field :recipients, component: :email_group_user, required: true
        field :query_id, component: :choices, required: true, extra: { content: queries }
        field :query_params, component: :"key-value", accepts_placeholders: true
        field :skip_empty, component: :boolean
        field :users_from_group, component: :boolean
        field :attach_csv,
              component: :boolean,
              validator: ->(attach_csv) do
                return if !attach_csv

                extensions = SiteSetting.authorized_extensions.split("|")
                if (extensions & %w[csv *]).empty?
                  I18n.t(
                    "discourse_automation.scriptables.recurring_data_explorer_result_pm.no_csv_allowed",
                  )
                end
              end

        version 1
        triggerables [:recurring]

        script do |_, fields, automation|
          recipients = Array(fields.dig("recipients", "value")).uniq
          query_id = fields.dig("query_id", "value")
          query_params = fields.dig("query_params", "value") || {}
          skip_empty = fields.dig("skip_empty", "value") || false
          users_from_group = fields.dig("users_from_group", "value") || false
          attach_csv = fields.dig("attach_csv", "value") || false

          unless SiteSetting.data_explorer_enabled
            Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - plugin must be enabled to run automation #{automation.id}"
            next
          end

          if recipients.blank?
            Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't find any recipients for automation #{automation.id}"
            next
          end

          DiscourseDataExplorer::ReportGenerator
            .generate(
              query_id,
              query_params,
              recipients,
              { skip_empty:, users_from_group:, attach_csv:, render_url_columns: true },
            )
            .each do |pm|
              utils.send_pm(pm, automation_id: automation.id)
            rescue ActiveRecord::RecordNotSaved => e
              Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't send PM for automation #{automation.id}: #{e.message}"
            end
        end
      end

      add_automation_scriptable("recurring_data_explorer_result_topic") do
        queries =
          DiscourseDataExplorer::Query
            .where(hidden: false)
            .map { |q| { id: q.id, translated_name: q.name } }
        field :topic_id, component: :text, required: true
        field :query_id, component: :choices, required: true, extra: { content: queries }
        field :query_params, component: :"key-value", accepts_placeholders: true
        field :skip_empty, component: :boolean
        field :attach_csv, component: :boolean

        version 1
        triggerables [:recurring]

        script do |_, fields, automation|
          topic_id = fields.dig("topic_id", "value")
          query_id = fields.dig("query_id", "value")
          query_params = fields.dig("query_params", "value") || {}
          skip_empty = fields.dig("skip_empty", "value") || false
          attach_csv = fields.dig("attach_csv", "value") || false

          unless SiteSetting.data_explorer_enabled
            Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - plugin must be enabled to run automation #{automation.id}"
            next
          end

          topic = Topic.find_by(id: topic_id)
          if topic.blank?
            Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't find topic ID (#{topic_id}) for automation #{automation.id}"
            next
          end

          begin
            post =
              DiscourseDataExplorer::ReportGenerator.generate_post(
                query_id,
                query_params,
                { skip_empty:, attach_csv:, render_url_columns: true },
              )

            next if post.empty?

            PostCreator.create!(
              Discourse.system_user,
              topic_id: topic.id,
              raw: post["raw"],
              skip_validations: true,
            )
          rescue ActiveRecord::RecordNotSaved => e
            Rails.logger.warn "#{DiscourseDataExplorer::PLUGIN_NAME} - couldn't reply to topic ID #{topic_id} for automation #{automation.id}: #{e.message}"
          end
        end
      end
    end
  end

  if defined?(DiscourseAi)
    require_relative "lib/discourse_data_explorer/ai_query_params"
    require_relative "lib/discourse_data_explorer/tools/find_queries"
    require_relative "lib/discourse_data_explorer/tools/run_sql"
    require_relative "lib/discourse_data_explorer/tools/submit_query"
    require_relative "lib/discourse_data_explorer/ai_query_generator"
    require_relative "lib/discourse_data_explorer/query_generation"
    require_relative "lib/discourse_data_explorer/admin_assistant/capability"
    require_relative "lib/discourse_data_explorer/admin_assistant/query_draft"
    require_relative "lib/discourse_data_explorer/admin_assistant/generate_query"
    require_relative "lib/discourse_data_explorer/admin_assistant/create_query"

    admin_assistant_tools = [
      DiscourseDataExplorer::AdminAssistant::GenerateQuery,
      DiscourseDataExplorer::AdminAssistant::CreateQuery,
    ]

    register_modifier(:admin_assistant_tools) { |tools, _agent| tools + admin_assistant_tools }

    DiscourseAi.register_tools(admin_assistant_tools, plugin: self)

    DiscourseAi.register_feature(
      module_name: :data_explorer,
      feature: :query_generation,
      agent_klass: DiscourseDataExplorer::AiQueryGenerator,
      enabled_by_setting: "data_explorer_ai_queries_enabled",
      plugin: self,
      entry_point: {
        path: "/admin/plugins/discourse-data-explorer/queries/new",
        label: "explorer.new_query",
      },
    )
  end

  register_stat("queries_total", stat_type: :de) { DiscourseDataExplorer::Statistics.queries_total }
  register_stat("queries_created", stat_type: :de) do
    DiscourseDataExplorer::Statistics.queries_created
  end
  register_stat("queries_edited", stat_type: :de) do
    DiscourseDataExplorer::Statistics.queries_edited
  end
  register_stat("queries_executed", stat_type: :de) do
    DiscourseDataExplorer::Statistics.queries_executed
  end
  register_stat("executions", stat_type: :de) { DiscourseDataExplorer::Statistics.executions }
end
