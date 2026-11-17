# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module WebHookSupport
      PAGE_LIMIT = 50
      MAX_CONTENT_LENGTH = 4_000
      MAX_INSPECTION_BYTES = 65_536
      ATTRIBUTES = %w[
        payload_url
        content_type
        secret
        active
        verify_certificate
        wildcard_web_hook
        event_type_ids
        category_ids
        tag_ids
        group_ids
      ].freeze
      RELATIONSHIPS = {
        "event_type_ids" => %w[web_hook_event_type_ids WebHookEventType],
        "category_ids" => %w[category_ids Category],
        "tag_ids" => %w[tag_ids Tag],
        "group_ids" => %w[group_ids Group],
      }.freeze
      CREDENTIAL_KEYS =
        /secret|token|password|passphrase|private.?key|api.?key|access.?key|authorization|cookie|signature|credential/i
      HOOK_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          destination_origin: OutputSchema::STRING_OR_NULL,
          destination_fingerprint: OutputSchema::STRING,
          content_type: OutputSchema::STRING_OR_NULL,
          last_delivery_status: OutputSchema::STRING_OR_NULL,
          active: OutputSchema::BOOLEAN,
          wildcard_web_hook: OutputSchema::BOOLEAN,
          verify_certificate: OutputSchema::BOOLEAN,
          secret_configured: OutputSchema::BOOLEAN,
          event_type_ids: OutputSchema::ARRAY,
          category_ids: OutputSchema::ARRAY,
          tag_ids: OutputSchema::ARRAY,
          group_ids: OutputSchema::ARRAY,
          relationships_truncated: OutputSchema::BOOLEAN,
        )
      EVENT_SCHEMA =
        OutputSchema.object(
          optional: %w[
            request_payload_preview
            response_body_preview
            content_truncated
            content_omitted
          ],
          id: OutputSchema::INTEGER,
          webhook_id: OutputSchema::INTEGER,
          status: OutputSchema::INTEGER,
          duration_ms: OutputSchema::INTEGER,
          created_at: OutputSchema::STRING_OR_NULL,
          redelivering: OutputSchema::BOOLEAN,
          request_payload_preview: OutputSchema::STRING_OR_NULL,
          response_body_preview: OutputSchema::STRING_OR_NULL,
          content_truncated: OutputSchema::BOOLEAN,
          content_omitted: OutputSchema::BOOLEAN,
        )

      module_function

      def find!(guardian, id)
        guardian.ensure_is_admin!
        WebHook.find_by(id:) || raise(ToolError, I18n.t("mcp.errors.webhook_not_found"))
      end

      def confirmed!(arguments, field)
        return if arguments[field] == true
        raise ToolError, I18n.t("mcp.errors.webhook_confirmation", field:)
      end

      def check_identity!(web_hook, arguments, active: false)
        if web_hook.destination_fingerprint != arguments["expected_destination_fingerprint"] ||
             (active && web_hook.active != arguments["expected_active"])
          raise ToolError, I18n.t("mcp.errors.webhook_changed")
        end
      end

      def lock!(web_hook)
        web_hook.lock!
      rescue ActiveRecord::RecordNotFound
        raise ToolError, I18n.t("mcp.errors.webhook_not_found")
      end

      def destination_origin(web_hook)
        uri = URI.parse(web_hook.payload_url)
        return unless uri.is_a?(URI::HTTP) && uri.host.present?
        uri.class.build(host: uri.host, port: uri.port).to_s
      rescue URI::InvalidURIError, URI::InvalidComponentError
        nil
      end

      def json(web_hook)
        relationships = {
          event_type_ids: web_hook.web_hook_event_types.map(&:id),
          category_ids: web_hook.categories.map(&:id),
          tag_ids: web_hook.tags.map(&:id),
          group_ids: web_hook.groups.map(&:id),
        }
        {
          id: web_hook.id,
          destination_origin: destination_origin(web_hook),
          destination_fingerprint: web_hook.destination_fingerprint,
          content_type: WebHook.content_types[web_hook.content_type],
          last_delivery_status:
            WebHook.last_delivery_statuses[
              (
                if web_hook.active
                  web_hook.last_delivery_status
                else
                  WebHook.last_delivery_statuses[:disabled]
                end
              )
            ]&.to_s,
          active: web_hook.active,
          wildcard_web_hook: web_hook.wildcard_web_hook,
          verify_certificate: web_hook.verify_certificate,
          secret_configured: web_hook.secret.present?,
          **relationships.transform_values { |ids| ids.first(100) },
          relationships_truncated: relationships.values.any? { |ids| ids.length > 100 },
        }
      end

      def catalog
        {
          event_types:
            WebHookEventType.active.map do |type|
              { id: type.id, name: type.name, group: type.group }
            end,
          content_types: WebHook.content_types.keys,
          delivery_statuses: WebHook.last_delivery_statuses.keys.map(&:to_s),
        }
      end

      def attributes(arguments, web_hook)
        result = arguments.slice(*ATTRIBUTES).deep_dup
        if result.key?("payload_url")
          result["payload_url"] = validate_destination!(result["payload_url"])
          if !web_hook.new_record? && result["payload_url"] != web_hook.payload_url &&
               result.fetch("active", web_hook.active)
            confirmed!(arguments, "confirm_external_delivery")
          end
          if URI.parse(result["payload_url"]).scheme == "http"
            confirmed!(arguments, "confirm_insecure_http")
          end
        end
        if result.key?("content_type")
          result["content_type"] = WebHook.content_types.fetch(result["content_type"])
        end
        confirmed!(arguments, "confirm_activate") if result["active"] == true && !web_hook.active
        if result["verify_certificate"] == false && web_hook.verify_certificate
          confirmed!(arguments, "confirm_disable_tls_verification")
        end
        if result["wildcard_web_hook"] == true && !web_hook.wildcard_web_hook
          confirmed!(arguments, "confirm_wildcard")
        end
        if !web_hook.new_record? && result.key?("secret") && result["secret"].blank?
          confirmed!(arguments, "confirm_clear_secret")
        end
        wildcard = result.fetch("wildcard_web_hook", web_hook.wildcard_web_hook)
        if wildcard && (result.key?("event_type_ids") || result["wildcard_web_hook"] == true)
          event_type_ids = result.fetch("event_type_ids") { web_hook.web_hook_event_type_ids }
          raise ToolError, I18n.t("mcp.errors.webhook_wildcard_events") if event_type_ids.present?
        end
        RELATIONSHIPS.each do |input_name, (attribute_name, class_name)|
          next unless result.key?(input_name)
          ids = result.delete(input_name)
          scope = class_name.constantize.all
          scope = scope.active if class_name == "WebHookEventType"
          if (ids - scope.where(id: ids).pluck(:id)).present?
            raise ToolError, I18n.t("mcp.errors.webhook_unknown_selection", field: input_name)
          end
          if !web_hook.new_record? && web_hook.public_send(attribute_name).sort != ids.sort
            confirmed!(arguments, "confirm_scope_replacement")
          end
          result[attribute_name] = ids
        end
        result
      end

      def validate_destination!(value)
        uri = URI.parse(value.strip)
        unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank? &&
                 uri.fragment.nil? && uri.port.between?(1, 65_535)
          raise ToolError, I18n.t("mcp.errors.webhook_invalid_destination")
        end
        uri.to_s
      rescue URI::InvalidURIError, URI::InvalidComponentError
        raise ToolError, I18n.t("mcp.errors.webhook_invalid_destination")
      end

      def changed_fields(web_hook, attributes)
        attributes.keys.select do |name|
          value = web_hook.public_send(name)
          name == "secret" ||
            (value.is_a?(Array) ? value.sort != attributes[name].sort : value != attributes[name])
        end
      end

      def log(guardian, web_hook, action, changed_fields: [], event_id: nil)
        StaffActionLogger.new(guardian.user).log_web_hook_operation(
          web_hook,
          action:,
          destination_origin: destination_origin(web_hook),
          destination_fingerprint: web_hook.destination_fingerprint,
          changed_fields:,
          event_id:,
        )
      end

      def event_json(event, web_hook, include_content: false, content_limit: 1_000)
        result = {
          id: event.id,
          webhook_id: event.web_hook_id,
          status: event.status,
          duration_ms: event.duration.to_i,
          created_at: event.created_at&.iso8601,
          redelivering: event.redelivering_webhook_event.present?,
        }
        if include_content
          payload = preview(event.payload, web_hook, content_limit)
          response = preview(event.response_body, web_hook, content_limit)
          result.merge!(
            request_payload_preview: payload[:text],
            response_body_preview: response[:text],
            content_truncated: payload[:truncated] || response[:truncated],
            content_omitted: payload[:omitted] || response[:omitted],
          )
        end
        result
      end

      def preview(value, web_hook, limit)
        if value.blank? || value.bytesize > MAX_INSPECTION_BYTES
          return { text: nil, truncated: false, omitted: value.present? }
        end
        data = JSON.parse(value)
        filter =
          ActiveSupport::ParameterFilter.new(
            Rails.application.config.filter_parameters + [CREDENTIAL_KEYS],
          )
        text = JSON.generate(filter.filter("content" => data)["content"])
        credentials = [web_hook.secret, web_hook.payload_url]
        uri = URI.parse(web_hook.payload_url)
        if uri.is_a?(URI::HTTP)
          credentials.concat([uri.request_uri, uri.path, uri.query, uri.user, uri.password])
          # Short standalone query values would mask unrelated prose and numeric IDs.
          credentials.concat(
            URI
              .decode_www_form(uri.query.to_s)
              .filter_map { |_, query_value| query_value if query_value.length >= 4 },
          )
        end
        credentials
          .reject { |credential| credential.blank? || credential == "/" }
          .uniq
          .sort_by { |credential| -credential.length }
          .each do |credential|
            encoded = JSON.generate(credential)[1...-1]
            text = text.gsub(encoded, "[FILTERED]") if text.include?(encoded)
          end
        { text: text.first(limit), truncated: text.length > limit, omitted: false }
      rescue JSON::ParserError,
             JSON::GeneratorError,
             Encoding::UndefinedConversionError,
             URI::Error,
             ArgumentError
        { text: nil, truncated: false, omitted: true }
      end
    end

    class ListWebhooks
      REQUIRED_SCOPES = [Scopes::WEBHOOKS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          optional: %w[catalog],
          webhooks: {
            type: "array",
            items: WebHookSupport::HOOK_SCHEMA,
          },
          has_more: OutputSchema::BOOLEAN,
          next_offset: OutputSchema::INTEGER_OR_NULL,
          catalog: OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        scope = WebHook.all
        scope = scope.where(active: arguments["active"]) if arguments.key?("active")
        if status = arguments["delivery_status"]
          scope =
            (
              if status == "disabled"
                scope.where(active: false)
              else
                scope.where(
                  active: true,
                  last_delivery_status: WebHook.last_delivery_statuses[status.to_sym],
                )
              end
            )
        end
        limit = arguments.fetch("limit", WebHookSupport::PAGE_LIMIT)
        offset = arguments.fetch("offset", 0)
        hooks =
          scope
            .offset(offset)
            .limit(limit + 1)
            .preload(:web_hook_event_types, :categories, :tags, :groups)
            .to_a
        has_more = hooks.length > limit
        result = {
          webhooks: hooks.first(limit).map { |hook| WebHookSupport.json(hook) },
          has_more:,
          next_offset: has_more ? offset + limit : nil,
        }
        result[:catalog] = WebHookSupport.catalog if arguments["include_catalog"]
        ToolHelpers.text_and_structured(result)
      end
    end

    class GetWebhook
      REQUIRED_SCOPES = ListWebhooks::REQUIRED_SCOPES
      OUTPUT_SCHEMA =
        OutputSchema.object(
          optional: %w[catalog],
          webhook: WebHookSupport::HOOK_SCHEMA,
          catalog: OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        hook = WebHookSupport.find!(request_context.guardian, arguments.fetch("webhook_id"))
        result = { webhook: WebHookSupport.json(hook) }
        result[:catalog] = WebHookSupport.catalog if arguments["include_catalog"]
        ToolHelpers.text_and_structured(result)
      end
    end

    class ListWebhookEvents
      REQUIRED_SCOPES = ListWebhooks::REQUIRED_SCOPES
      OUTPUT_SCHEMA =
        OutputSchema.object(
          webhook_id: OutputSchema::INTEGER,
          events: {
            type: "array",
            items: WebHookSupport::EVENT_SCHEMA,
          },
          has_more: OutputSchema::BOOLEAN,
          next_offset: OutputSchema::INTEGER_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        hook = WebHookSupport.find!(request_context.guardian, arguments.fetch("webhook_id"))
        include_content = arguments.fetch("include_content", false)
        if include_content
          WebHookSupport.confirmed!(arguments, "confirm_sensitive_content")
          # Delivery bodies can contain private messages without a reliable payload discriminator.
          request_context.ensure_scopes!([Scopes::PRIVATE_MESSAGES_READ])
        end
        events =
          hook
            .web_hook_events
            .reorder(created_at: :desc, id: :desc)
            .preload(:redelivering_webhook_event)
        events = events.successful if arguments["status"] == "successful"
        events = events.failed if arguments["status"] == "failed"
        columns = %i[id web_hook_id status duration created_at]
        if include_content
          columns += [
            Arel.sql(
              "LEFT(web_hook_events.payload, ?) AS payload",
              WebHookSupport::MAX_INSPECTION_BYTES + 1,
            ),
            Arel.sql(
              "LEFT(web_hook_events.response_body, ?) AS response_body",
              WebHookSupport::MAX_INSPECTION_BYTES + 1,
            ),
          ]
        end
        limit = arguments.fetch("limit", WebHookSupport::PAGE_LIMIT)
        offset = arguments.fetch("offset", 0)
        rows = events.select(*columns).offset(offset).limit(limit + 1).to_a
        has_more = rows.length > limit
        ToolHelpers.text_and_structured(
          webhook_id: hook.id,
          events:
            rows
              .first(limit)
              .map do |event|
                WebHookSupport.event_json(
                  event,
                  hook,
                  include_content:,
                  content_limit: arguments.fetch("content_limit", 1_000),
                )
              end,
          has_more:,
          next_offset: has_more ? offset + limit : nil,
        )
      end
    end

    class CreateWebhook
      REQUIRED_SCOPES = [Scopes::WEBHOOKS_WRITE].freeze
      OUTPUT_SCHEMA = OutputSchema.object(webhook: WebHookSupport::HOOK_SCHEMA)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_is_admin!
        WebHookSupport.confirmed!(arguments, "confirm_external_delivery")
        hook = WebHook.new
        attributes = WebHookSupport.attributes(arguments, hook)
        WebHook.transaction do
          hook.assign_attributes(attributes)
          hook.save!
          WebHookSupport.log(guardian, hook, :web_hook_create, changed_fields: attributes.keys)
        end
        ToolHelpers.text_and_structured(webhook: WebHookSupport.json(hook))
      rescue FinalDestination::SSRFDetector::LookupFailedError
        raise ToolError, I18n.t("mcp.errors.webhook_destination_unreachable")
      end
    end

    class UpdateWebhook
      REQUIRED_SCOPES = CreateWebhook::REQUIRED_SCOPES
      OUTPUT_SCHEMA = CreateWebhook::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        hook = WebHookSupport.find!(guardian, arguments.fetch("webhook_id"))
        WebHookSupport.confirmed!(arguments, "confirm_update")
        WebHook.transaction do
          WebHookSupport.lock!(hook)
          WebHookSupport.check_identity!(hook, arguments, active: true)
          attributes = WebHookSupport.attributes(arguments, hook)
          fields = WebHookSupport.changed_fields(hook, attributes)
          raise ToolError, I18n.t("mcp.errors.webhook_no_change") if fields.empty?
          hook.update!(attributes)
          WebHookSupport.log(guardian, hook, :web_hook_update, changed_fields: fields)
        end
        ToolHelpers.text_and_structured(webhook: WebHookSupport.json(hook.reload))
      rescue FinalDestination::SSRFDetector::LookupFailedError
        raise ToolError, I18n.t("mcp.errors.webhook_destination_unreachable")
      end
    end

    class DeleteWebhook
      REQUIRED_SCOPES = CreateWebhook::REQUIRED_SCOPES
      OUTPUT_SCHEMA =
        OutputSchema.object(deleted: OutputSchema::BOOLEAN, webhook_id: OutputSchema::INTEGER)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        hook = WebHookSupport.find!(guardian, arguments.fetch("webhook_id"))
        WebHookSupport.confirmed!(arguments, "confirm_delete")
        WebHook.transaction do
          WebHookSupport.lock!(hook)
          WebHookSupport.check_identity!(hook, arguments)
          hook.destroy!
          WebHookSupport.log(guardian, hook, :web_hook_destroy)
        end
        ToolHelpers.text_and_structured(deleted: true, webhook_id: hook.id)
      end
    end

    class PingWebhook
      REQUIRED_SCOPES = CreateWebhook::REQUIRED_SCOPES
      OUTPUT_SCHEMA =
        OutputSchema.object(
          webhook_id: OutputSchema::INTEGER,
          enqueued: OutputSchema::BOOLEAN,
          delivery_succeeded: OutputSchema::BOOLEAN_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        hook = WebHookSupport.find!(guardian, arguments.fetch("webhook_id"))
        WebHookSupport.confirmed!(arguments, "confirm_external_request")
        WebHookSupport.check_identity!(hook, arguments)
        WebHookSupport.log(guardian, hook, :web_hook_ping)
        Jobs.enqueue(
          :emit_web_hook_event,
          web_hook_id: hook.id,
          event_type: "ping",
          event_name: "ping",
          skip_retry: true,
          expected_destination_fingerprint: hook.destination_fingerprint,
        )
        ToolHelpers.text_and_structured(
          webhook_id: hook.id,
          enqueued: true,
          delivery_succeeded: nil,
        )
      end
    end

    class RedeliverWebhookEvent
      REQUIRED_SCOPES = CreateWebhook::REQUIRED_SCOPES
      OUTPUT_SCHEMA =
        OutputSchema.object(
          webhook_id: OutputSchema::INTEGER,
          event_id: OutputSchema::INTEGER,
          attempted: OutputSchema::BOOLEAN,
          delivery_succeeded: OutputSchema::BOOLEAN,
          event: WebHookSupport::EVENT_SCHEMA,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        hook = WebHookSupport.find!(guardian, arguments.fetch("webhook_id"))
        WebHookSupport.confirmed!(arguments, "confirm_redelivery")
        WebHookSupport.check_identity!(hook, arguments)
        event = hook.web_hook_events.find_by(id: arguments.fetch("event_id"))
        raise ToolError, I18n.t("mcp.errors.webhook_event_not_found") unless event
        headers, claim =
          begin
            event.with_lock do
              headers = JSON.parse(event.headers.presence || "{}")
              if event.status != arguments["expected_event_status"] ||
                   RedeliveringWebhookEvent.exists?(web_hook_event_id: event.id)
                raise ToolError, I18n.t("mcp.errors.webhook_changed")
              end
              if event.status == 0 || !headers.is_a?(Hash) ||
                   headers.any? { |name, value|
                     name.casecmp?("x-discourse-event-type") && value == "ping"
                   }
                raise ToolError, I18n.t("mcp.errors.webhook_event_not_deliverable")
              end
              [
                headers,
                RedeliveringWebhookEvent.create!(web_hook_event_id: event.id, processing: true),
              ]
            end
          rescue ActiveRecord::RecordNotFound
            raise ToolError, I18n.t("mcp.errors.webhook_event_not_found")
          end
        begin
          # Keep result persistence bound to the same parent snapshot as the outbound request.
          hook.web_hook_event_types.load unless hook.wildcard_web_hook
          event.web_hook = hook
          WebHookSupport.log(guardian, hook, :web_hook_redeliver, event_id: event.id)
          WebHookEmitter.new(hook, event).emit!(headers:, body: event.payload)
        ensure
          RedeliveringWebhookEvent.where(id: claim.id).delete_all
          event.association(:redelivering_webhook_event).reset
        end
        ToolHelpers.text_and_structured(
          webhook_id: hook.id,
          event_id: event.id,
          attempted: true,
          delivery_succeeded: event.status.between?(200, 299),
          event: WebHookSupport.event_json(event, hook),
        )
      rescue JSON::ParserError
        raise ToolError, I18n.t("mcp.errors.webhook_event_not_deliverable")
      end
    end
  end
end
