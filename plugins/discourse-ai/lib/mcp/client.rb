# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class Client
      MCP_SESSION_ID_HEADER = "Mcp-Session-Id"
      JSONRPC_VERSION = "2.0"
      PROTOCOL_VERSION = "2025-11-25"
      MODERN_PROTOCOL_VERSION = "2026-07-28"
      SUPPORTED_CLASSIC_PROTOCOL_VERSIONS = [PROTOCOL_VERSION, "2025-03-26"].freeze
      SUPPORTED_PROTOCOL_VERSIONS = [
        MODERN_PROTOCOL_VERSION,
        *SUPPORTED_CLASSIC_PROTOCOL_VERSIONS,
      ].freeze
      MODERN_ERROR_CODES = [-32_020, -32_021, -32_022].freeze
      DISCOVERY_TOLERATED_STATUSES = [400, 404, 405].freeze
      CLASSIC_INITIALIZE_TOLERATED_STATUSES = [400].freeze
      POST_JSONRPC_OPTIONS = %i[
        params
        session_id
        accept_sse
        notification
        allow_result_error
        tolerate_statuses
        input_schema
        allow_oauth_retry
      ].freeze
      PROTOCOL_META_KEY = "io.modelcontextprotocol/protocolVersion"
      CLIENT_INFO_META_KEY = "io.modelcontextprotocol/clientInfo"
      CAPABILITIES_META_KEY = "io.modelcontextprotocol/clientCapabilities"
      USER_AGENT = "Discourse AI MCP Client"
      MAX_RESPONSE_BODY_LENGTH = 5.megabytes

      Error = Class.new(StandardError)
      AuthorizationRequiredError = Class.new(Error)
      SessionExpiredError = Class.new(Error)
      UnauthorizedError =
        Class.new(Error) do
          attr_reader :challenge_header

          def initialize(message = nil, challenge_header: nil)
            @challenge_header = challenge_header
            super(message)
          end
        end

      Response = Struct.new(:payload, :session_id, :status, :headers, keyword_init: true)

      attr_reader :protocol_version

      def initialize(server, protocol_version: nil)
        @server = server
        if protocol_version.present? && !SUPPORTED_PROTOCOL_VERSIONS.include?(protocol_version)
          raise Error,
                I18n.t(
                  "discourse_ai.mcp_servers.errors.unsupported_protocol_version",
                  version: protocol_version,
                )
        end
        @protocol_version = protocol_version
      end

      def initialize_session
        @protocol_version = MODERN_PROTOCOL_VERSION
        probe = post_jsonrpc("server/discover", tolerate_statuses: DISCOVERY_TOLERATED_STATUSES)
        error = probe.payload["error"] if probe.payload.is_a?(Hash)
        if probe.payload.is_a?(Hash) && probe.payload["jsonrpc"] == JSONRPC_VERSION &&
             error.is_a?(Hash) && MODERN_ERROR_CODES.include?(error["code"])
          if error["code"] == -32_022
            supported = error["data"].is_a?(Hash) ? error["data"]["supported"] : nil
            supported = supported.is_a?(Array) ? supported : []
            version = SUPPORTED_PROTOCOL_VERSIONS.find { |candidate| supported.include?(candidate) }
            if version.nil?
              raise Error, I18n.t("discourse_ai.mcp_servers.errors.no_supported_version")
            end
            return initialize_classic_session(version) if version != MODERN_PROTOCOL_VERSION
          end

          raise_response_error!(
            probe.payload,
            fallback: "discourse_ai.mcp_servers.errors.modern_request_rejected",
          )
        end

        return initialize_classic_session if classic_fallback?(probe)

        raise_response_error!(probe.payload, status: probe.status) if probe.status >= 400

        result = extract_result!(probe.payload)
        unless result["supportedVersions"].is_a?(Array) &&
                 result["supportedVersions"].include?(MODERN_PROTOCOL_VERSION)
          raise Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_discovery_response")
        end

        { session_id: nil, result: result.merge("protocolVersion" => MODERN_PROTOCOL_VERSION) }
      end

      def initialize_classic_session(offer = PROTOCOL_VERSION)
        if SUPPORTED_CLASSIC_PROTOCOL_VERSIONS.exclude?(offer)
          raise Error,
                I18n.t(
                  "discourse_ai.mcp_servers.errors.unsupported_protocol_version",
                  version: offer,
                )
        end

        @protocol_version = nil
        response =
          post_jsonrpc(
            "initialize",
            params: {
              protocolVersion: offer,
              capabilities: {
                tools: {
                },
              },
              clientInfo: {
                name: USER_AGENT,
                version: Discourse::VERSION::STRING,
              },
            },
            tolerate_statuses: CLASSIC_INITIALIZE_TOLERATED_STATUSES,
          )

        if offer == PROTOCOL_VERSION && rejected_classic_version?(response.payload)
          return initialize_classic_session("2025-03-26")
        end
        raise_response_error!(response.payload, status: response.status) if response.status >= 400

        result = extract_result!(response.payload)
        version = result["protocolVersion"]
        if version.blank?
          raise Error, I18n.t("discourse_ai.mcp_servers.errors.missing_protocol_version")
        end
        if !SUPPORTED_CLASSIC_PROTOCOL_VERSIONS.include?(version)
          raise Error,
                I18n.t(
                  "discourse_ai.mcp_servers.errors.unsupported_protocol_version",
                  version: version,
                )
        end

        @protocol_version = version
        notify_initialized(response.session_id)

        { session_id: response.session_id, result: result }
      end

      def list_tools(session_id: nil)
        response = post_jsonrpc("tools/list", session_id: session_id)
        result = extract_result!(response.payload)
        Array(result["tools"]).reject do |tool|
          next false if protocol_version != MODERN_PROTOCOL_VERSION
          next true unless tool.is_a?(Hash)

          begin
            HeaderMapper.new(tool["inputSchema"]).annotations
            false
          rescue Error => error
            Rails.logger.warn("Invalid MCP tool #{tool["name"]}: #{error.message}")
            true
          end
        end
      end

      def call_tool(tool_name, arguments, session_id: nil, input_schema: nil)
        if protocol_version == MODERN_PROTOCOL_VERSION && input_schema.nil?
          tool = list_tools.find { |definition| definition["name"] == tool_name }
          if tool.nil?
            raise Error, I18n.t("discourse_ai.mcp_servers.errors.tool_unavailable", name: tool_name)
          end

          input_schema = tool["inputSchema"]
        end

        response =
          post_jsonrpc(
            "tools/call",
            params: {
              name: tool_name,
              arguments: arguments,
            },
            session_id: session_id,
            input_schema: input_schema,
            accept_sse: true,
            allow_result_error: true,
          )

        extract_result!(response.payload)
      end

      private

      attr_reader :server

      def notify_initialized(session_id)
        post_jsonrpc("notifications/initialized", session_id: session_id, notification: true)
      rescue Error => e
        Rails.logger.warn(
          "Discourse AI MCP initialize notification failed for server #{server.id}: #{e.message}",
        )
      end

      def post_jsonrpc(method, **options)
        options.assert_valid_keys(*POST_JSONRPC_OPTIONS)
        uri = validate_uri!
        params = options[:params]
        session_id = options[:session_id]

        if protocol_version == MODERN_PROTOCOL_VERSION
          params =
            (params || {}).merge(
              _meta: {
                PROTOCOL_META_KEY => protocol_version,
                CLIENT_INFO_META_KEY => {
                  name: USER_AGENT,
                  version: Discourse::VERSION::STRING,
                },
                CAPABILITIES_META_KEY => {
                },
              },
            )
        end

        payload = { jsonrpc: JSONRPC_VERSION, method: method }
        payload[:params] = params if params.present?
        payload[:id] = SecureRandom.uuid unless options[:notification]

        headers = default_headers(session_id: session_id)
        if protocol_version == MODERN_PROTOCOL_VERSION
          headers.merge!(
            HeaderMapper.request_headers(method, params, input_schema: options[:input_schema]),
          )
        end
        response, raw_body = perform_request(uri, payload, headers)

        handle_response(
          response,
          raw_body,
          session_id: session_id,
          allow_result_error: options[:allow_result_error],
          tolerate_statuses: options.fetch(:tolerate_statuses, []),
        )
      rescue UnauthorizedError => e
        if server.oauth? && options.fetch(:allow_oauth_retry, true) &&
             server.oauth_token_store.refresh_token.present?
          DiscourseAi::Mcp::OAuthFlow.refresh!(server)

          return post_jsonrpc(method, **options.merge(allow_oauth_retry: false))
        end

        discovery =
          DiscourseAi::Mcp::OAuthDiscovery.discover!(server, challenge_header: e.challenge_header)
        server.store_oauth_discovery!(discovery) if server.persisted?

        raise AuthorizationRequiredError,
              I18n.t(
                "discourse_ai.mcp_servers.errors.oauth_authorization_required",
                issuer: discovery.issuer,
              )
      rescue AuthorizationRequiredError
        raise
      rescue Net::ReadTimeout, Net::OpenTimeout
        raise Error, I18n.t("discourse_ai.mcp_servers.errors.timeout")
      rescue JSON::ParserError
        raise Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
      end

      def perform_request(uri, payload, headers)
        response = nil
        raw_body = +""
        total_bytes = 0

        FinalDestination::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: server.timeout_seconds,
          read_timeout: server.timeout_seconds,
        ) do |http|
          request = FinalDestination::HTTP::Post.new(uri.request_uri)
          request["User-Agent"] = USER_AGENT
          headers.each { |key, value| request[key] = value }
          request.body = payload.to_json

          http.request(request) do |http_response|
            response = http_response
            http_response.read_body do |chunk|
              total_bytes += chunk.bytesize
              ensure_response_body_limit!(total_bytes)
              raw_body << chunk
            end
          end
        end

        [response, raw_body]
      end

      def handle_response(response, raw_body, session_id:, allow_result_error:, tolerate_statuses:)
        status = response.code.to_i

        if status == 404 && session_id.present? && protocol_version != MODERN_PROTOCOL_VERSION
          raise SessionExpiredError, I18n.t("discourse_ai.mcp_servers.errors.session_expired")
        end

        if status == 401 && server.oauth?
          raise UnauthorizedError.new(
                  I18n.t("discourse_ai.mcp_servers.errors.request_failed", status: status),
                  challenge_header: response["WWW-Authenticate"],
                )
        end

        body =
          begin
            if response["Content-Type"].to_s.include?("text/event-stream")
              parse_sse_body(raw_body)
            else
              parse_json_body(raw_body)
            end
          rescue JSON::ParserError
            unless tolerate_statuses == DISCOVERY_TOLERATED_STATUSES &&
                     tolerate_statuses.include?(status)
              raise
            end

            {}
          end

        return build_response(response, body, status) if tolerate_statuses.include?(status)

        if status < 200 || status >= 300
          if allow_result_error && tool_result_error?(body)
            return build_response(response, body, status)
          end

          raise_response_error!(body, status: status)
        end

        build_response(response, body, status)
      end

      def parse_json_body(body)
        return {} if body.blank?

        JSON.parse(body)
      end

      def parse_sse_body(raw_body)
        events = []
        buffer = raw_body.dup

        while (separator = sse_separator_end(buffer))
          event = parse_sse_event(buffer.slice!(0, separator))
          events << event if event.present?
        end

        event = parse_sse_event(buffer)
        events << event if event.present?

        events.reverse_each.find do |payload|
          payload.is_a?(Hash) && (payload.key?("result") || payload.key?("error"))
        end || {}
      end

      def default_headers(session_id:)
        ensure_oauth_access_token! if server.oauth?

        headers = {
          "Content-Type" => "application/json",
          "Accept" => "application/json, text/event-stream",
        }
        if server.auth_header.present? && (auth_header_value = server.auth_header_value).present?
          headers[server.auth_header] = auth_header_value
        end

        headers["MCP-Protocol-Version"] = protocol_version if protocol_version.present?
        headers[MCP_SESSION_ID_HEADER] = session_id if session_id.present? &&
          protocol_version != MODERN_PROTOCOL_VERSION
        headers
      end

      def classic_fallback?(response)
        return true if response.status == 400
        return method_not_found?(response.payload) if response.status == 200
        return false if [404, 405].exclude?(response.status)

        method_not_found?(response.payload) || !response.payload.is_a?(Hash) ||
          response.payload["jsonrpc"] != JSONRPC_VERSION
      end

      def method_not_found?(payload)
        payload.is_a?(Hash) && payload["jsonrpc"] == JSONRPC_VERSION &&
          payload["error"].is_a?(Hash) && payload["error"]["code"] == -32_601
      end

      def rejected_classic_version?(payload)
        return false unless payload.is_a?(Hash) && payload["jsonrpc"] == JSONRPC_VERSION

        error = payload["error"]
        return false unless error.is_a?(Hash) && error["code"].is_a?(Integer)
        return false if MODERN_ERROR_CODES.include?(error["code"])

        message = error["message"]
        message.is_a?(String) &&
          message.match?(
            /\b(?:unsupported|unrecognized|not supported|invalid)\s+(?:MCP\s+)?protocol\s+version\b|\bprotocol\s+version\b.*\b(?:unsupported|unrecognized|not supported|invalid)\b/i,
          )
      end

      def raise_response_error!(
        payload,
        status: nil,
        fallback: "discourse_ai.mcp_servers.errors.request_failed"
      )
        error = payload["error"] if payload.is_a?(Hash)
        message = error["message"] if error.is_a?(Hash)
        raise Error, message.presence || I18n.t(fallback, status: status)
      end

      def extract_result!(payload)
        unless payload.is_a?(Hash)
          raise Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
        end

        if payload["error"].present?
          raise_response_error!(
            payload,
            fallback: "discourse_ai.mcp_servers.errors.invalid_response",
          )
        end

        result = payload["result"] || {}
        unless result.is_a?(Hash)
          raise Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
        end

        result
      end

      def build_response(response, body, status)
        Response.new(
          payload: body,
          session_id: response[MCP_SESSION_ID_HEADER],
          status: status,
          headers: response.to_hash,
        )
      end

      def tool_result_error?(body)
        body.is_a?(Hash) && body.dig("result", "isError") == true
      end

      def validate_uri!
        uri = AiMcpServer.parse_public_uri(server.url)
        raise Error, I18n.t("discourse_ai.mcp_servers.invalid_url_not_https") if uri.nil?

        AiMcpServer.validate_hostname_public!(uri.hostname)
        uri
      rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError
        raise Error, I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable")
      end

      def ensure_response_body_limit!(size)
        return if size <= MAX_RESPONSE_BODY_LENGTH

        raise Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
      end

      def ensure_oauth_access_token!
        return if !server.oauth? || !server.oauth_needs_refresh?

        DiscourseAi::Mcp::OAuthFlow.refresh!(server)
      end

      def sse_separator_end(buffer)
        buffer.match(/\r?\n\r?\n/)&.end(0)
      end

      def parse_sse_event(raw_event)
        data =
          raw_event
            .lines(chomp: true)
            .grep(/\Adata:/)
            .map { |line| line.sub(/\Adata:\s?/, "") }
            .join("\n")

        return if data.blank? || data == "[DONE]"

        JSON.parse(data)
      end
    end
  end
end
