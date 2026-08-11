# frozen_string_literal: true

module DiscourseMcp
  class Server
    PAGE_SIZE = 50
    SERVER_INFO_META_KEY = "io.modelcontextprotocol/serverInfo"
    PROTOCOL_META_KEY = "io.modelcontextprotocol/protocolVersion"
    CAPABILITIES_META_KEY = "io.modelcontextprotocol/clientCapabilities"

    Response = Data.define(:http_status, :body, :headers)

    def initialize(request:, principal:)
      @request = request
      @principal = principal
      @profile = principal.profile
      @catalog = Catalog.new(profile: @profile, principal: principal)
    end

    def call(payload)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      mcp_response = process(payload)
      record_audit(payload, mcp_response, started_at)
      mcp_response
    end

    def process(payload)
      validate_request!(payload)
      id = payload["id"]
      method = payload["method"]
      params = payload["params"].is_a?(Hash) ? payload["params"] : {}
      result = dispatch(method, params)

      return Response.new(http_status: 202, body: nil, headers: {}) if id.nil?

      Response.new(http_status: 200, body: success(id, result), headers: {})
    rescue DiscourseMcp::Error => error
      Response.new(
        http_status: error.http_status,
        body: failure(payload&.dig("id"), error),
        headers: error.headers,
      )
    rescue DiscourseMcp::ToolError => error
      result = complete_result(content: [{ type: "text", text: error.message }], isError: true)
      Response.new(http_status: 200, body: success(payload&.dig("id"), result), headers: {})
    rescue Discourse::InvalidAccess
      error = Error.new("Not authorized", code: -32_001, http_status: 403)
      Response.new(http_status: 403, body: failure(payload&.dig("id"), error), headers: {})
    rescue JSONSchemer::InvalidSchema => error
      protocol_error = Error.new("Invalid schema", code: -32_000, http_status: 500)
      Discourse.warn_exception(error, message: "MCP schema validation failed")
      Response.new(http_status: 500, body: failure(payload&.dig("id"), protocol_error), headers: {})
    rescue StandardError => error
      protocol_error = Error.new("Internal error", code: -32_603, http_status: 500)
      Discourse.warn_exception(error, message: "MCP request failed")
      Response.new(http_status: 500, body: failure(payload&.dig("id"), protocol_error), headers: {})
    end
    private :process

    private

    attr_reader :request, :principal, :profile, :catalog

    def record_audit(payload, mcp_response, started_at)
      return if !payload.is_a?(Hash) || payload["method"] != "tools/call"

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      tool_error =
        mcp_response.body&.dig(:result, :isError) || mcp_response.body&.dig("result", "isError")
      McpAuditLog.create!(
        occurred_at: Time.zone.now,
        user_id: principal.user_id,
        mcp_oauth_client_id: principal.oauth_client_id,
        mcp_server_profile_id: principal.profile_id,
        request_id: payload["id"].to_s.presence,
        method: payload["method"],
        capability: payload.dig("params", "name").to_s.first(255),
        outcome: mcp_response.http_status < 400 && !tool_error ? "success" : "error",
        http_status: mcp_response.http_status,
        duration_ms: duration_ms,
      )
    rescue StandardError => error
      Discourse.warn_exception(error, message: "MCP audit record failed")
    end

    def validate_request!(payload)
      raise Error.new("Invalid Request", code: -32_600) if !payload.is_a?(Hash)
      raise Error.new("Invalid Request", code: -32_600) if payload["jsonrpc"] != JSONRPC_VERSION
      raise Error.new("Invalid Request", code: -32_600) if payload["method"].blank?

      return validate_initialize_request!(payload) if payload["method"] == "initialize"

      header_version = request.headers["MCP-Protocol-Version"]
      if !SUPPORTED_PROTOCOL_VERSIONS.include?(header_version)
        raise Error.new(
                "Unsupported protocol version",
                code: -32_022,
                data: {
                  supported: SUPPORTED_PROTOCOL_VERSIONS,
                },
              )
      end

      body_version = payload.dig("params", "_meta", PROTOCOL_META_KEY)
      if header_version == PROTOCOL_VERSION
        validate_dated_request_metadata!(payload, header_version, body_version)
      elsif body_version.present? && body_version != header_version
        raise Error.new(
                "HTTP headers do not match request metadata",
                code: -32_020,
                data: {
                  header: "MCP-Protocol-Version",
                },
              )
      end
    end

    def validate_initialize_request!(payload)
      requested_version = payload.dig("params", "protocolVersion")
      raise Error.new("Missing protocol version", code: -32_602) if requested_version.blank?
    end

    def validate_dated_request_metadata!(payload, header_version, body_version)
      if body_version.blank? || header_version != body_version
        raise Error.new(
                "HTTP headers do not match request metadata",
                code: -32_020,
                data: {
                  header: "MCP-Protocol-Version",
                },
              )
      end

      method_header = request.headers["Mcp-Method"]
      if method_header.blank? || method_header != payload["method"]
        raise Error.new(
                "HTTP headers do not match request body",
                code: -32_020,
                data: {
                  header: "Mcp-Method",
                },
              )
      end

      if %w[tools/call resources/read prompts/get].include?(payload["method"])
        expected_name =
          payload.dig("params", payload["method"] == "resources/read" ? "uri" : "name")
        actual_name = decode_header(request.headers["Mcp-Name"])
        if expected_name.blank? || actual_name != expected_name
          raise Error.new(
                  "HTTP headers do not match request body",
                  code: -32_020,
                  data: {
                    header: "Mcp-Name",
                  },
                )
        end
      end

      capabilities = payload.dig("params", "_meta", CAPABILITIES_META_KEY)
      if !capabilities.is_a?(Hash)
        raise Error.new("Missing required client capability metadata", code: -32_021)
      end
    end

    def dispatch(method, params)
      case method
      when "initialize"
        initialize_result(params)
      when "notifications/initialized", "notifications/cancelled",
           "notifications/roots/list_changed"
        {}
      when "ping"
        {}
      when "server/discover"
        discover
      when "tools/list"
        list_tools(params)
      when "tools/call"
        call_tool(params)
      when "resources/list"
        list_resources(params)
      when "resources/templates/list"
        list_resource_templates(params)
      when "resources/read"
        read_resource(params)
      when "prompts/list"
        list_prompts(params)
      when "prompts/get"
        get_prompt(params)
      else
        raise Error.new("Method not found", code: -32_601, http_status: 404)
      end
    end

    def initialize_result(params)
      requested_version = params["protocolVersion"]
      negotiated_version =
        if SUPPORTED_PROTOCOL_VERSIONS.include?(requested_version)
          requested_version
        else
          PROTOCOL_VERSION
        end
      result = {
        protocolVersion: negotiated_version,
        capabilities: server_capabilities,
        serverInfo: {
          name: SERVER_NAME,
          title: "Discourse MCP Server",
          version: Discourse::VERSION::STRING,
        },
      }
      result[:instructions] = profile.instructions if profile.instructions.present?
      result
    end

    def server_capabilities
      {
        tools: {
          listChanged: false,
        },
        resources: {
          subscribe: false,
          listChanged: false,
        },
        prompts: {
          listChanged: false,
        },
      }
    end

    def discover
      result = {
        supportedVersions: SUPPORTED_PROTOCOL_VERSIONS,
        capabilities: server_capabilities,
        ttlMs: profile.cache_ttl_ms,
        cacheScope: "private",
      }
      result[:instructions] = profile.instructions if profile.instructions.present?
      complete_result(**result)
    end

    def list_tools(params)
      page, next_cursor = paginate(catalog.list(:tool), params["cursor"])
      tools =
        page.map do |tool|
          value = {
            name: tool.identifier,
            title: tool.title,
            description: tool.description,
            inputSchema: tool.input_schema,
            annotations: tool.annotations,
          }
          value[:outputSchema] = tool.output_schema if tool.output_schema
          value
        end
      complete_result(
        tools: tools,
        nextCursor: next_cursor,
        ttlMs: profile.cache_ttl_ms,
        cacheScope: "private",
      )
    end

    def call_tool(params)
      tool = authorized_capability(:tool, params["name"], "Unknown tool")

      arguments = params["arguments"].is_a?(Hash) ? params["arguments"] : {}
      errors = JSONSchemer.schema(tool.input_schema).validate(arguments).to_a
      if errors.present?
        raise Error.new("Invalid tool arguments", code: -32_602, data: { errors: errors.first(20) })
      end

      result = tool.implementation.call(arguments: arguments, principal: principal)
      complete_result(**result.symbolize_keys)
    rescue ActiveRecord::RecordInvalid => error
      raise ToolError, error.record.errors.full_messages.join(", ")
    rescue Discourse::InvalidParameters
      raise ToolError, "The operation parameters are invalid"
    end

    def list_resources(params)
      complete_result(resources: [], ttlMs: profile.cache_ttl_ms, cacheScope: "private")
    end

    def list_resource_templates(params)
      templates =
        catalog
          .list(:resource_template)
          .map do |resource|
            {
              uriTemplate: uri_template(resource.identifier),
              name: resource.identifier,
              title: resource.title,
              description: resource.description,
            }
          end
      complete_result(
        resourceTemplates: templates,
        ttlMs: profile.cache_ttl_ms,
        cacheScope: "private",
      )
    end

    def read_resource(params)
      uri = params["uri"].to_s
      resource = catalog.find_exposed(:resource_template, resource_identifier(uri))
      raise Error.new("Resource not found", code: -32_602) if resource.blank?
      ensure_scopes!(resource)

      content = resource.implementation.call(uri: uri, principal: principal)
      complete_result(contents: [content], ttlMs: profile.cache_ttl_ms, cacheScope: "private")
    end

    def list_prompts(params)
      prompts =
        catalog
          .list(:prompt)
          .map do |prompt|
            properties = prompt.input_schema["properties"] || {}
            required = Array(prompt.input_schema["required"])
            arguments =
              properties.map do |name, schema|
                {
                  name: name,
                  description: schema["description"],
                  required: required.include?(name),
                }.compact
              end
            {
              name: prompt.identifier,
              title: prompt.title,
              description: prompt.description,
              arguments: arguments,
            }
          end
      complete_result(prompts: prompts, ttlMs: profile.cache_ttl_ms, cacheScope: "private")
    end

    def get_prompt(params)
      prompt = authorized_capability(:prompt, params["name"], "Prompt not found")
      arguments = params["arguments"].is_a?(Hash) ? params["arguments"] : {}
      errors = JSONSchemer.schema(prompt.input_schema).validate(arguments).to_a
      if errors.present?
        raise Error.new(
                "Invalid prompt arguments",
                code: -32_602,
                data: {
                  errors: errors.first(20),
                },
              )
      end
      complete_result(
        **prompt.implementation.call(arguments: arguments, principal: principal).symbolize_keys,
      )
    end

    def complete_result(**values)
      values.compact.merge(
        resultType: "complete",
        _meta: {
          SERVER_INFO_META_KEY => {
            name: SERVER_NAME,
            version: Discourse::VERSION::STRING,
          },
        },
      )
    end

    def success(id, result)
      { jsonrpc: JSONRPC_VERSION, id: id, result: result }
    end

    def failure(id, error)
      value = { code: error.code, message: error.message }
      value[:data] = error.data if error.data
      { jsonrpc: JSONRPC_VERSION, id: id, error: value }
    end

    def paginate(values, cursor)
      offset = cursor.present? ? Base64.urlsafe_decode64(cursor).to_i : 0
      page = values.slice(offset, PAGE_SIZE) || []
      next_cursor = Base64.urlsafe_encode64((offset + PAGE_SIZE).to_s, padding: false) if offset +
        PAGE_SIZE < values.length
      [page, next_cursor]
    rescue ArgumentError
      raise Error.new("Invalid cursor", code: -32_602)
    end

    def decode_header(value)
      return if value.blank?
      return value if !value.start_with?("=?base64?") || !value.end_with?("?=")

      Base64.strict_decode64(value.delete_prefix("=?base64?").delete_suffix("?="))
    rescue ArgumentError
      raise Error.new("Invalid encoded header", code: -32_020)
    end

    def uri_template(identifier)
      {
        "discourse.topic" => "discourse://topic/{topic_id}",
        "discourse.post" => "discourse://post/{post_id}",
      }.fetch(identifier, "discourse://#{identifier}/{id}")
    end

    def resource_identifier(uri)
      return "discourse.topic" if uri.match?(%r{\Adiscourse://topic/\d+\z})
      return "discourse.post" if uri.match?(%r{\Adiscourse://post/\d+\z})

      DiscourseMcp
        .registry
        .all(:resource_template)
        .find do |capability|
          uri.match?(%r{\Adiscourse://#{Regexp.escape(capability.identifier)}/\d+\z})
        end
        &.identifier
    end

    def authorized_capability(kind, identifier, not_found_message)
      capability = catalog.find_exposed(kind, identifier)
      raise Error.new(not_found_message, code: -32_602) if capability.blank?

      ensure_scopes!(capability)
      capability
    end

    def ensure_scopes!(capability)
      missing = capability.required_scopes.reject { |scope| principal.scopes.include?(scope) }
      return if missing.empty?

      required_scopes = capability.required_scopes.join(" ")
      raise Error.new(
              "Insufficient scope",
              code: -32_001,
              http_status: 403,
              data: {
                required_scopes: capability.required_scopes,
              },
              headers: {
                "WWW-Authenticate" =>
                  Authenticator.challenge(scope: required_scopes, error: "insufficient_scope"),
              },
            )
    end
  end
end
