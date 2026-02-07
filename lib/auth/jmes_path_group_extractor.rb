# frozen_string_literal: true

module Auth
  class JmesPathGroupExtractor
    DISCOURSE_CONNECT = "discourse_connect"
    # Extract groups from OAuth/SAML auth token
    def self.extract_groups(auth_token)
      return [] if !SiteSetting.jmespath_group_mapping_enabled

      provider_name = auth_token[:provider]
      searchable_data = auth_token.deep_stringify_keys

      extract_groups_from_data(searchable_data, provider_name)
    end

    # Extract groups from DiscourseConnect payload
    def self.extract_groups_from_discourse_connect(discourse_connect_payload)
      return [] if !SiteSetting.jmespath_group_mapping_enabled

      searchable_data = discourse_connect_payload.deep_stringify_keys

      # Discourse connect transforms [custom_field][X] into custom.X keys
      # We need to transform them back into nested custom_fields structure for JMESPath
      custom_fields = {}
      searchable_data =
        searchable_data.reject do |key, value|
          if key.start_with?("custom.")
            field_name = key.sub("custom.", "")
            custom_fields[field_name] = value
            true
          else
            false
          end
        end

      searchable_data["custom_fields"] = custom_fields if custom_fields.present?

      extract_groups_from_data(searchable_data, DISCOURSE_CONNECT)
    end

    private

    def self.extract_groups_from_data(searchable_data, provider_name)
      rules = Auth::JmespathGroupMappingRulesSchema.values

      valid_provider_rules =
        rules.select do |rule|
          next false unless rule.enabled.nil? || rule.enabled == true

          rule_provider = rule.provider || "*"
          rule_provider == "*" || rule_provider == provider_name
        end

      groups = []

      valid_provider_rules.each do |rule|
        begin
          result = JMESPath.search(rule.expression, searchable_data)

          if result && result.present?
            rule.groups.each { |group_name| groups << { id: group_name, name: group_name } }
          end
        rescue JMESPath::Errors::SyntaxError => e
          Rails.logger.warn(
            "[JMESPath] Invalid expression syntax '#{rule.expression}': #{e.message}",
          )
        rescue StandardError => e
          Rails.logger.warn(
            "[JMESPath] Failed to evaluate expression '#{rule.expression}': #{e.message}",
          )
        end
      end

      groups.uniq
    end
  end
end
