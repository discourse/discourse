# frozen_string_literal: true

require "json_schemer"
require "discourse_mcp"
require "discourse_mcp/primitive"
require "discourse_mcp/registry"
require "discourse_mcp/access"
require "discourse_mcp/authorization_status"
require "discourse_mcp/request_context"
require "discourse_mcp/catalog"
require "discourse_mcp/authenticator"
require "discourse_mcp/server"
require "discourse_mcp/oauth"
require "discourse_mcp/core_tools"
require "discourse_mcp/core_primitives"

DiscourseMcp.reset_registry!

DiscourseEvent.on(:site_setting_changed) do |name, _old_value, _new_value|
  if %i[mcp_oauth_client_id_metadata_policy mcp_oauth_client_id_metadata_domains].include?(name)
    DiscourseMcp::OAuth::ClientResolver.revoke_disallowed_clients!
  end
end
