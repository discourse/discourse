# frozen_string_literal: true

require_relative "server_support"

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  shared_examples "restricted typed theme settings" do |shape|
    it "[cr-u3] GetTheme conceals restricted #{shape} values and defaults independently" do
      denied_category = Fabricate(:category, id: 91_300_011)
      allowed_category = Fabricate(:category, id: 91_300_012)
      denied_tag = Fabricate(:tag, id: 91_300_013, name: "cru3-theme-denied")
      allowed_tag = Fabricate(:tag, id: 91_300_014, name: "cru3-theme-allowed")
      denied, allowed, definition =
        case shape
        when "category_list"
          [
            denied_category.id.to_s,
            allowed_category.id.to_s,
            { "type" => "list", "list_type" => "category" },
          ]
        when "tag_list"
          [denied_tag.name, allowed_tag.name, { "type" => "list", "list_type" => "tag" }]
        else
          [
            [{ "categories" => [denied_category.id], "tags" => [denied_tag.name] }],
            [{ "categories" => [allowed_category.id], "tags" => [allowed_tag.name] }],
            {
              "type" => "objects",
              "schema" => {
                "name" => "references",
                "properties" => {
                  "categories" => {
                    "type" => "categories",
                  },
                  "tags" => {
                    "type" => "tags",
                  },
                },
              },
            },
          ]
        end
      theme = Fabricate(:theme)
      definitions = {
        "restricted_value" => definition.merge("default" => allowed),
        "restricted_default" => definition.merge("default" => denied),
        "allowed_control" => definition.merge("default" => allowed),
      }
      theme.set_field(
        target: :settings,
        name: :yaml,
        value: JSON.parse(JSON.generate(definitions)).to_yaml,
      )
      theme.save!
      theme.update_setting(:restricted_value, denied)
      theme.update_setting(:restricted_default, allowed)
      baseline = rpc("discourse_get_theme", "theme_id" => theme.id)
      expect_usable(baseline)
      payloads(baseline).each do |payload|
        settings = payload.fetch("theme").fetch("settings").index_by { |row| row.fetch("setting") }
        expect(settings.fetch("restricted_value").fetch("value")).to eq(denied)
        expect(settings.fetch("restricted_default").fetch("default")).to eq(denied)
        expect(settings.fetch("restricted_default").fetch("value")).to eq(allowed)
      end

      forum_rule(denied_categories: [denied_category.id], denied_tags: [denied_tag.id])
      response = rpc("discourse_get_theme", "theme_id" => theme.id)
      expect_usable(response)

      aggregate_failures do
        payloads(response).each_with_index do |payload, index|
          settings = payload.fetch("theme").fetch("settings")
          expect_absent(
            settings.map { |row| row.slice("setting", "value", "default") },
            [denied_category.id, denied_category.name, denied_tag.id, denied_tag.name],
            "GetTheme #{shape} payload #{index}",
          )
          expect(settings.find { |row| row["setting"] == "allowed_control" }).to include(
            "value" => allowed,
            "default" => allowed,
          )
        end
      end
    end
  end

  include_examples "restricted typed theme settings", "category_list"
  include_examples "restricted typed theme settings", "tag_list"
  include_examples "restricted typed theme settings", "objects"
end
