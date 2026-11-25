# frozen_string_literal: true

require_relative "server_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include McpContentRestrictionsUnit3::ServerSupport

  %w[forum_content private_messages].each do |kind|
    %i[value default].each do |field|
      it "[cr-u3] conceals an invalid UTF-8 decoded host in setting #{field} under #{kind} without an error" do
        original_default = SiteSetting.defaults[:tos_url]
        malformed = "https://%FF.example/page"
        external = "https://external.example/terms"
        SiteSetting.defaults.set_regardless_of_locale(
          :tos_url,
          field == :default ? malformed : external,
        )
        SiteSetting.tos_url = field == :value ? malformed : external

        unrestricted = rpc("discourse_list_site_settings", "names" => ["tos_url"])
        expect_usable(unrestricted)
        payloads(unrestricted).each do |payload|
          expect(payload.fetch("site_settings").sole).to include(field.to_s => malformed)
        end

        if kind == "forum_content"
          forum_rule
        else
          McpContentRule.create!(rule_kind: kind, config: {})
        end

        response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
        expect_usable(response)
        payloads(response).each do |payload|
          expect(payload.fetch("site_settings").sole).to include(
            "value" => nil,
            "default" => nil,
            "redacted" => true,
          )
        end
      ensure
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
