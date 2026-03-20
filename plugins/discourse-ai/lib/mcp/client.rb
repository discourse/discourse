# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class Client
      MCP_SESSION_ID_HEADER = "Mcp-Session-Id"
      JSONRPC_VERSION = "2.0"
      PROTOCOL_VERSION = "2025-03-26"
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

      def initialize(server)
        @server = server
      end

      def initialize_session
        response =
          post_jsonrpc(
            "initialize",
            params: {
              protocolVersion: PROTOCOL_VERSION,
              capabilities: {
                tools: {
                },
              },
              clientInfo: {
                name: USER_AGENT,
                version: Discourse::VERSION::STRING,
              },
            },
          )

        result = extract_result!(response.payload)
        notify_initialized(response.session_id)

        { session_id: response.session_id, result: result }
      end

      def list_tools(session_id: nil)
        response = post_jsonrpc("tools/list", session_id: session_id)
        result = extract_result!(response.payload)
        Array(result["tools"])
      end

      def call_tool(tool_name, arguments, session_id: nil)
        response =
          post_jsonrpc(
            "tools/call",
            params: {
              name: tool_name,
              arguments: arguments,
            },
            session_id: session_id,
            accept_sse: true,
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

      def post_jsonrpc(
        method,
        params: nil,
        session_id: nil,
        accept_sse: false,
        notification: false,
        allow_oauth_retry: true
      )
        uri = validate_uri!

        payload = { jsonrpc: JSONRPC_VERSION, method: method }
        payload[:params] = params if params.present?
        payload[:id] = SecureRandom.uuid unless notification

        headers = default_headers(session_id: session_id)
        response, raw_body = perform_request(uri, payload, headers)

        handle_response(response, raw_body, session_id: session_id)
      rescue UnauthorizedError => e
        if server.oauth? && allow_oauth_retry && server.oauth_token_store.refresh_token.present?
          DiscourseAi::Mcp::OAuthFlow.refresh!(server)

          return(
            post_jsonrpc(
              method,
              params: params,
              session_id: session_id,
              accept_sse: accept_sse,
              notification: notification,
              allow_oauth_retry: false,
            )
          )
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

      def handle_response(response, raw_body, session_id:)
        status = response.code.to_i

        if status == 404 && session_id.present?
          raise SessionExpiredError, I18n.t("discourse_ai.mcp_servers.errors.session_expired")
        end

        if status == 401 && server.oauth?
          raise UnauthorizedError.new(
                  I18n.t("discourse_ai.mcp_servers.errors.request_failed", status: status),
                  challenge_header: response["WWW-Authenticate"],
                )
        end

        body =
          if response["Content-Type"].to_s.include?("text/event-stream")
            parse_sse_body(raw_body)
          else
            parse_json_body(raw_body)
          end

        if status < 200 || status >= 300
          message = body.is_a?(Hash) ? body.dig("error", "message") : nil
          raise Error,
                message.presence ||
                  I18n.t("discourse_ai.mcp_servers.errors.request_failed", status: status)
        end

        Response.new(
          payload: body,
          session_id: response[MCP_SESSION_ID_HEADER],
          status: status,
          headers: response.to_hash,
        )
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

        if server.auth_header.present? && server.auth_header_value.present?
          headers[server.auth_header] = server.auth_header_value
        end

        headers[MCP_SESSION_ID_HEADER] = session_id if session_id.present?
        headers
      end

      def extract_result!(payload)
        error = payload["error"]
        if error.present?
          raise Error,
                error["message"].presence ||
                  I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
        end

        payload["result"] || {}
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
