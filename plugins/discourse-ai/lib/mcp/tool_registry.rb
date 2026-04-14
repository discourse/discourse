# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class ToolRegistry
      CACHE_VERSION = 1
      CACHE_TTL = 1.hour

      class << self
        def cache_key(server_id)
          current_db = RailsMultisite::ConnectionManagement.current_db
          "discourse-ai:mcp-tools:v#{CACHE_VERSION}:#{current_db}:#{server_id}"
        end

        def invalidate!(server_id)
          Rails.cache.delete(cache_key(server_id))
        end

        def tool_definitions_for(server)
          payload = Rails.cache.read(cache_key(server.id))

          return refresh!(server, raise_on_error: false) if payload.blank?

          if Time.zone.parse(payload["expires_at"]) <= Time.zone.now
            Jobs.enqueue(:refresh_ai_mcp_server_tools, ai_mcp_server_id: server.id)
          end

          Array(payload["definitions"])
        rescue ArgumentError
          refresh!(server, raise_on_error: false)
        end

        def refresh!(server, raise_on_error: false)
          client = DiscourseAi::Mcp::Client.new(server)
          initialized = client.initialize_session
          definitions = client.list_tools(session_id: initialized[:session_id])
          write_cache(server.id, definitions)

          server.update_columns(
            last_health_status: "healthy",
            last_health_error: nil,
            last_checked_at: Time.zone.now,
            last_tools_synced_at: Time.zone.now,
            protocol_version: initialized[:result]["protocolVersion"],
            server_capabilities: initialized[:result]["capabilities"] || {},
          )

          definitions
        rescue StandardError => e
          server.update_columns(
            last_health_status: "error",
            last_health_error: e.message.truncate(1000),
            last_checked_at: Time.zone.now,
          )

          cached = Rails.cache.read(cache_key(server.id))
          return Array(cached&.dig("definitions")) if cached.present? && !raise_on_error

          raise if raise_on_error

          []
        end

        def tool_classes_for_servers(servers, reserved_names: [], selected_tool_names_by_server: {})
          servers = Array(servers).select { |server| !server.oauth? || server.oauth_connected? }

          definitions_by_server =
            servers.each_with_object({}) do |server, hash|
              definitions = tool_definitions_for(server)
              selected_tool_names =
                normalize_selected_tool_names(selected_tool_names_by_server, server)

              hash[server] = if selected_tool_names.blank?
                definitions
              else
                definitions.select do |definition|
                  selected_tool_names.include?(definition["name"].to_s)
                end
              end
            end

          original_names =
            definitions_by_server.values.flatten.filter_map do |definition|
              definition["name"].presence
            end
          name_counts = original_names.tally
          taken_names = reserved_names.map(&:downcase).to_set

          definitions_by_server.flat_map do |server, definitions|
            definitions.filter_map do |definition|
              tool_name = definition["name"].to_s
              next if tool_name.blank?

              function_name =
                unique_function_name(
                  tool_name,
                  server,
                  taken_names,
                  needs_namespace: name_counts[tool_name].to_i > 1,
                )

              taken_names << function_name.downcase

              DiscourseAi::Agents::Tools::Mcp.class_instance(
                server.id,
                tool_name,
                definition,
                function_name: function_name,
              )
            end
          end
        end

        private

        def normalize_selected_tool_names(selected_tool_names_by_server, server)
          selected_tool_names_by_server[server.id] || selected_tool_names_by_server[server.id.to_s]
        end

        def write_cache(server_id, definitions)
          now = Time.zone.now
          Rails.cache.write(
            cache_key(server_id),
            {
              "definitions" => definitions,
              "fetched_at" => now.iso8601,
              "expires_at" => (now + CACHE_TTL).iso8601,
            },
            expires_in: CACHE_TTL * 2,
          )
        end

        def unique_function_name(original_name, server, taken_names, needs_namespace:)
          candidate = original_name

          if needs_namespace || taken_names.include?(candidate.downcase)
            prefix = server.name.to_s.parameterize(separator: "_").presence || "server_#{server.id}"
            candidate = "#{prefix}__#{original_name}"
          end

          suffix = 2
          while taken_names.include?(candidate.downcase)
            candidate = "#{candidate}_#{suffix}"
            suffix += 1
          end

          candidate
        end
      end
    end
  end
end
