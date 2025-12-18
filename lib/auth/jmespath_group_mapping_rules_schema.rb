# frozen_string_literal: true

module Auth
  class JmespathGroupMappingRulesSchema
    def self.schema
      {
        type: "array",
        uniqueItems: false,
        items: {
          type: "object",
          title: "JMESPath Group Mapping Rule",
          required: %w[expression group],
          properties: {
            provider: {
              type: "string",
              title: "Provider",
              description:
                "Provider name (google_oauth2, saml, oidc, discourse_connect, etc.), use * or leave empty for all providers",
              default: "*",
            },
            expression: {
              type: "string",
              title: "JMESPath Expression",
              description: "JMESPath expression to evaluate against auth_token.",
              minLength: 1,
            },
            groups: {
              type: "array",
              title: "Discourse Group",
              description: "Name of the Discourse group(s) to assign users to",
              minLength: 1,
            },
            enabled: {
              type: "boolean",
              title: "Enabled",
              description: "Whether this rule is active",
              default: true,
            },
            description: {
              type: "string",
              title: "Description",
              description: "Optional description of what this rule does (for documentation)",
            },
          },
        },
        description: "Configure group assignment rules using JMESPath expressions.",
      }
    end

    def self.values
      return [] if SiteSetting.jmes_group_mapping_rules_by_attributes.blank?
      JSON.parse(SiteSetting.jmes_group_mapping_rules_by_attributes, object_class: OpenStruct)
    end
  end
end
