# frozen_string_literal: true

require "enum_site_setting"

class McpOauthClientIdMetadataPolicy < EnumSiteSetting
  def self.valid_value?(value)
    values.any? { |policy| policy[:value] == value }
  end

  def self.values
    @values ||= [
      { name: "mcp_oauth_client_id_metadata_policy.disabled", value: "disabled" },
      { name: "mcp_oauth_client_id_metadata_policy.approved_domains", value: "approved_domains" },
      { name: "mcp_oauth_client_id_metadata_policy.any_domain", value: "any_domain" },
    ]
  end

  def self.translate_names?
    true
  end
end
