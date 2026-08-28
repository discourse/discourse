# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLogsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      LIST_LIMIT = 50
      MAX_DATE_RANGE = 366.days
      MAX_RETENTION_DAYS = 36_500
      MAX_PAYLOAD_BYTES = 1.megabyte
      MIN_PAYLOAD_CHARACTERS = MAX_PAYLOAD_BYTES / 4
      MAX_SEARCH_LENGTH = 200
      MAX_ID = 2**63 - 1
      DETAIL_COLUMNS = %i[
        id
        provider_id
        user_id
        request_tokens
        response_tokens
        created_at
        topic_id
        post_id
        feature_name
        language_model
        feature_context
        duration_msecs
        time_to_first_token_msecs
        cache_write_tokens
        cache_read_tokens
        llm_id
        response_status
        request_attempts
        estimated_cost
      ].freeze
      LIST_COLUMNS = %i[
        id
        created_at
        provider_id
        feature_name
        language_model
        llm_id
        user_id
        topic_id
        post_id
        request_tokens
        response_tokens
        response_status
        duration_msecs
      ].freeze
      BOOLEAN_VALUES = %w[true false].freeze

      def index
        limit = page_limit
        logs = filtered_logs
        if params[:cursor] && params[:id].blank?
          logs = logs.where("ai_api_audit_logs.id < ?", positive_integer!(:cursor))
        end
        logs =
          logs
            .select(
              *LIST_COLUMNS,
              Arel.sql("request_attempts IS NOT NULL AS has_retries"),
              Arel.sql(
                "CASE WHEN #{AiApiAuditLog::SUCCESS_CONDITION} THEN 'successful' ELSE 'failed' END AS outcome",
              ),
            )
            .order(id: :desc)
            .limit(limit + 1)
            .preload(:user, :llm_model)
            .to_a

        has_more = logs.length > limit
        logs = logs.first(limit)

        response = {
          logs:
            ActiveModel::ArraySerializer.new(
              logs,
              each_serializer: DiscourseAi::Admin::AiLogListSerializer,
              root: false,
            ).as_json,
          meta: {
            next_cursor: has_more ? logs.last&.id : nil,
            has_more:,
            max_id: AiApiAuditLog.maximum(:id),
          },
        }

        if boolean_param(:include_meta)
          response[:meta].merge!(retention_metadata)
          response[:models] = LlmModel
            .order(:display_name)
            .pluck(:id, :display_name)
            .map { |id, name| { id:, name: } }
          response[:features] = DiscourseAi::Configuration::Feature
            .all
            .map(&:name)
            .compact
            .uniq
            .sort
        end

        render json: response
      end

      def new_logs
        since_id = since_id_param
        count = filtered_logs.where("ai_api_audit_logs.id > ?", since_id).count
        render json: { new_logs_count: count }
      end

      def show
        log =
          AiApiAuditLog
            .select(
              *DETAIL_COLUMNS,
              Arel.sql(payload_projection_sql(:raw_request_payload)),
              Arel.sql(payload_projection_sql(:raw_response_payload)),
              Arel.sql("OCTET_LENGTH(raw_request_payload) AS raw_request_payload_bytes"),
              Arel.sql("OCTET_LENGTH(raw_response_payload) AS raw_response_payload_bytes"),
            )
            .preload(:user, :llm_model)
            .find(positive_integer!(:id))
        render json: DiscourseAi::Admin::AiLogDetailSerializer.new(log, root: false)
      end

      def update_retention
        detailed_days = non_negative_integer!(:detailed_days)
        summary_days = non_negative_integer!(:summary_days)

        if detailed_days.positive? && summary_days.positive? && summary_days < detailed_days
          raise Discourse::InvalidParameters.new(:summary_days)
        end

        SiteSetting::Update.call(
          guardian:,
          params: {
            settings: [
              { setting_name: :ai_audit_logs_detailed_retention_days, value: detailed_days },
              { setting_name: :ai_audit_logs_purge_after_days, value: summary_days },
            ],
          },
        ) do
          on_success do
            render json: {
                     retention: {
                       detailed_days: SiteSetting.ai_audit_logs_detailed_retention_days,
                       summary_days: SiteSetting.ai_audit_logs_purge_after_days,
                     },
                   }
          end
          on_failed_policy(:settings_are_unshadowed_globally) do |policy|
            raise Discourse::InvalidParameters, policy.reason
          end
          on_failed_policy(:settings_are_visible) do |policy|
            raise Discourse::InvalidParameters, policy.reason
          end
          on_failed_policy(:settings_are_configurable) do |policy|
            raise Discourse::InvalidParameters, policy.reason
          end
          on_failed_policy(:settings_are_not_deprecated) do |policy|
            raise Discourse::InvalidParameters, policy.reason
          end
          on_failed_contract do |contract|
            raise Discourse::InvalidParameters, contract.errors.full_messages.join(", ")
          end
          on_failure { raise Discourse::InvalidParameters, :retention }
        end
      end

      private

      def payload_projection_sql(column)
        <<~SQL.squish
          LEFT(
            #{column},
            GREATEST(
              #{MIN_PAYLOAD_CHARACTERS},
              #{MAX_PAYLOAD_BYTES} - (OCTET_LENGTH(#{column}) - CHAR_LENGTH(#{column}))
            )
          ) AS #{column}
        SQL
      end

      def filtered_logs
        validate_filter_params!
        scope = AiApiAuditLog.all

        id_filters = %i[id topic_id post_id].select { |name| params[name].present? }
        raise Discourse::InvalidParameters.new(:id) if id_filters.length > 1

        if id_filters.one?
          name = id_filters.first
          scope = scope.where(name => positive_integer!(name))
        end

        scope = apply_date_filters(scope)
        scope = apply_outcome_filter(scope)
        scope = scope.where.not(request_attempts: nil) if boolean_param(:has_retries)
        scope = scope.where(llm_id: params[:llm_id]) if params[:llm_id].present?
        scope = scope.where(feature_name: params[:feature].to_s) if params[:feature].present?
        scope = apply_search_filter(scope) if params[:search].present?

        if boolean_param(:unattributed) &&
             (params[:user_id].present? || params[:username].present? || search_usernames.any?)
          raise Discourse::InvalidParameters.new(:unattributed)
        end

        if params[:user_id].present? || params[:username].present?
          user_id =
            if params[:user_id].present?
              positive_integer!(:user_id)
            else
              User.find_by_username(params[:username].to_s)&.id || -1
            end
          scope = scope.where(user_id:)
        elsif boolean_param(:unattributed)
          scope = scope.where(user_id: nil)
        end

        scope
      end

      def apply_date_filters(scope)
        return scope if params[:start_date].blank? && params[:end_date].blank?

        timezone =
          if params[:timezone].present?
            ActiveSupport::TimeZone[params[:timezone].to_s] ||
              (raise Discourse::InvalidParameters.new(:timezone))
          else
            Time.zone
          end

        start_time = parse_time!(:start_date, timezone, :beginning) if params[:start_date].present?
        end_time = parse_time!(:end_date, timezone, :end) if params[:end_date].present?

        if start_time && end_time &&
             (end_time < start_time || end_time - start_time > MAX_DATE_RANGE)
          raise Discourse::InvalidParameters.new(:date_range)
        end

        scope = scope.where("ai_api_audit_logs.created_at >= ?", start_time) if start_time
        scope = scope.where("ai_api_audit_logs.created_at <= ?", end_time) if end_time
        scope
      end

      def parse_time!(name, timezone, boundary)
        value = params[name].to_s
        parsed = timezone.parse(value)
        raise Discourse::InvalidParameters.new(name) if !parsed

        if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          boundary == :end ? parsed.end_of_day : parsed.beginning_of_day
        else
          Time.iso8601(value)
        end
      rescue ArgumentError
        raise Discourse::InvalidParameters.new(name)
      end

      def apply_search_filter(scope)
        parsed = parsed_search

        parsed[:ids].each { |column, value| scope = scope.where(column => value) }

        parsed[:numerics].each do |value|
          scope =
            scope.where(
              "ai_api_audit_logs.id = ? OR ai_api_audit_logs.topic_id = ? OR ai_api_audit_logs.post_id = ?",
              value,
              value,
              value,
            )
        end

        if parsed[:usernames].any?
          clause = Array.new(parsed[:usernames].length, "users.username ILIKE ?").join(" AND ")
          values = parsed[:usernames].map { |value| "%#{value}%" }
          scope = scope.joins(:user).where(clause, *values)
        end

        scope
      end

      def search_usernames
        params[:search].present? ? parsed_search[:usernames] : []
      end

      def parsed_search
        return @parsed_search if @parsed_search

        search = params[:search].to_s.strip
        raise Discourse::InvalidParameters.new(:search) if search.length > MAX_SEARCH_LENGTH

        id_columns = { "log" => "id", "topic" => "topic_id", "post" => "post_id" }
        parsed = { ids: [], numerics: [], usernames: [] }

        search
          .split(/\s+/)
          .each do |token|
            if (match = token.match(/\A(log|topic|post):(\d+)\z/))
              parsed[:ids] << [id_columns.fetch(match[1]), bounded_positive_id!(match[2])]
            elsif token.match?(/\A\d+\z/)
              parsed[:numerics] << bounded_positive_id!(token)
            else
              username = token.delete_prefix("@")
              if username.present?
                parsed[:usernames] << username.gsub(/[\\%_]/) { |char| "\\#{char}" }
              end
            end
          end

        @parsed_search = parsed
      end

      def bounded_positive_id!(value)
        parsed = Integer(value, exception: false)
        raise Discourse::InvalidParameters.new(:search) if !positive_id?(parsed)

        parsed
      end

      def apply_outcome_filter(scope)
        case params[:outcome]
        when nil, ""
          scope
        when "successful"
          scope.successful_requests
        when "failed"
          scope.failed_requests
        else
          raise Discourse::InvalidParameters.new(:outcome)
        end
      end

      def validate_filter_params!
        %i[has_retries unattributed include_meta].each do |name|
          next if params[name].blank? || BOOLEAN_VALUES.include?(params[name].to_s)

          raise Discourse::InvalidParameters.new(name)
        end
      end

      def boolean_param(name)
        params[name].to_s == "true"
      end

      def page_limit
        return LIST_LIMIT if params[:limit].blank?

        [positive_integer!(:limit), LIST_LIMIT].min
      end

      def positive_integer!(name)
        value = Integer(params[name], exception: false)
        raise Discourse::InvalidParameters.new(name) if !positive_id?(value)

        value
      end

      # anything wider than a bigint overflows the column comparison in Postgres
      def positive_id?(value)
        value&.positive? && value <= MAX_ID
      end

      def non_negative_integer!(name)
        value = Integer(params[name], exception: false)
        if !value || value.negative? || value > MAX_RETENTION_DAYS
          raise Discourse::InvalidParameters.new(name)
        end

        value
      end

      def since_id_param
        value = Integer(params[:since_id], exception: false)
        if !value || value.negative? || value > MAX_ID
          raise Discourse::InvalidParameters.new(:since_id)
        end

        value
      end

      def retention_metadata
        total_bytes =
          DB.query_single("SELECT pg_total_relation_size('ai_api_audit_logs')").first.to_i

        {
          retention: {
            detailed_days: SiteSetting.ai_audit_logs_detailed_retention_days,
            summary_days: SiteSetting.ai_audit_logs_purge_after_days,
          },
          storage: {
            total_bytes:,
          },
        }
      end
    end
  end
end
