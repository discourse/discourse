# frozen_string_literal: true

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
