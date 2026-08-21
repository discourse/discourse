# frozen_string_literal: true

require "discourse_mcp"
require "discourse_mcp/capability"
require "discourse_mcp/registry"
require "discourse_mcp/principal"
require "discourse_mcp/catalog"
require "discourse_mcp/authenticator"
require "discourse_mcp/server"
require "discourse_mcp/oauth"
require "discourse_mcp/core_tools"
require "discourse_mcp/core_capabilities"

DiscourseMcp.reset_registry!
