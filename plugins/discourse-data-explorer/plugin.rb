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
register_svg_icon "upload"

add_admin_route "explorer.title", "discourse-data-explorer", use_new_show_route: true

module ::DiscourseDataExplorer
  PLUGIN_NAME = "discourse-data-explorer"

  # This should always match the max value for the
  # data_explorer_query_result_limit site setting
  QUERY_RESULT_MAX_LIMIT = 10_000
end

require_relative "lib/discourse_data_explorer/engine"

# Render datetimes in TimeWithZone's native format rather than running Graphiti's
# :datetime read-coercer, which does `time.to_datetime.iso8601` — and since AR
# hands it a TimeWithZone, `to_datetime` triggers a Rational/tzinfo allocation
# storm (the single biggest serialization cost). This is scoped to :datetime ONLY,
# so every other type keeps its normal read coercion — unlike a global
# `typecast_reads = false`, which also changes integer_id-attribute / decimal /
# custom-coerced output (verified against Graphiti's own suite: only datetime
# serialization specs differ). Must run BEFORE resources load: serializer attribute
# procs capture the read coercer at class-definition time, so this lives at plugin
# top-level (pre-eager-load), not in after_initialize.
# Trade-off: datetimes emit TimeWithZone's format (ms precision + "Z") instead of
# DateTime#iso8601 ("+00:00", no fractional). See docs/api-modernization-exploration.md.
if defined?(Graphiti)
  Graphiti::Types[:datetime] = Graphiti::Types[:datetime].merge(read: ->(value) { value })
end

# Thin-layers JSON:API spike: jsonapi-serializer for rendering. The jsonapi.rb gem was
# dropped entirely (its Ransack-based filtering breaks core, and its other mixins —
# include/fields/pagination/deserialization — were small enough to absorb into
# JsonapiRb::BaseController). The thin stack now depends only on jsonapi-serializer + pagy.
require "jsonapi/serializer"
# Patch jsonapi-serializer's nested-include linkage bug (lazy_load_data + nested leaf drops
# the leaf's linkage). Small, owned, on a frozen gem. See the patch file + Part 9.
require_relative "lib/discourse_data_explorer/jsonapi_rb/lazy_nested_linkage_patch"
FastJsonapi::SerializationCore::ClassMethods.prepend(
  DiscourseDataExplorer::JsonapiRb::LazyNestedLinkagePatch,
)

after_initialize do
  # PERF-TEMP (benchmarking only): Graphiti concurrency is a process-wide, memoized
  # switch. Toggle it per-boot (GRAPHITI_CONCURRENCY=off) to measure both regimes
  # against the thin-layers endpoint. Runs before the first request → before the
  # executor memoizes. Remove after the perf comparison (Part 9).
  Graphiti.config.concurrency = false if defined?(Graphiti) && ENV["GRAPHITI_CONCURRENCY"] == "off"

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

  # JSON:API modernization spike (Graphiti): the many_to_many sideload on
  # QueryResource matches groups back to queries via group.query_groups.
  reloadable_patch do
    Group.has_many :query_groups, class_name: "DiscourseDataExplorer::QueryGroup"

    # Hash-indexed many_to_many sideload assignment (O(children × through +
    # parents) instead of stock O(parents × children × through)). See
    # lib/discourse_data_explorer/graphiti_patches/many_to_many_performant_assign.rb.
    if defined?(Graphiti)
      Graphiti::Sideload::ManyToMany.prepend(
        DiscourseDataExplorer::GraphitiPatches::ManyToManyPerformantAssign,
      )

      # Memoize jsonapi-serializable's per-exposure ivar names (avoids a String
      # allocation per key/object/record). Behavior-identical; ~16% fewer
      # serialization allocations. See the patch file for details.
      JSONAPI::Serializable::Resource.prepend(
        DiscourseDataExplorer::GraphitiPatches::CachedExposureIvars::ResourceInit,
      )
      JSONAPI::Serializable::Relationship.prepend(
        DiscourseDataExplorer::GraphitiPatches::CachedExposureIvars::RelationshipInit,
      )
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
        params: %i[id],
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

    DiscourseAi.register_feature(
      module_name: :data_explorer,
      feature: :query_generation,
      agent_klass: DiscourseDataExplorer::AiQueryGenerator,
      enabled_by_setting: "data_explorer_ai_queries_enabled",
      plugin: self,
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
