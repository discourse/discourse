# frozen_string_literal: true

require_relative "read_tool_support"

describe DiscourseMcp::Server do
  include McpContentReadHelpers

  describe "GetTheme" do
    shared_examples "restricted typed theme settings" do |shape|
      it "conceals restricted #{shape} values and defaults separately" do
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
          settings =
            payload.fetch("theme").fetch("settings").index_by { |row| row.fetch("setting") }
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

    shared_examples "typed content references" do |property_type, rule_kind|
      it "conceals top-level and nested #{property_type} values and defaults under #{rule_kind}" do
        denied_category = Fabricate(:category)
        restricted_topic =
          if rule_kind == "private_messages"
            Fabricate(:private_message_topic, id: 92_310_001, user: admin)
          else
            Fabricate(:topic, id: 92_310_001, user: admin, category: denied_category)
          end
        restricted_post = Fabricate(:post, id: 93_310_001, topic: restricted_topic, user: admin)
        allowed_topic = Fabricate(:topic, user: admin)
        allowed_post = Fabricate(:post, topic: allowed_topic, user: admin)
        restricted_id = property_type == "topic" ? restricted_topic.id : restricted_post.id
        allowed_id = property_type == "topic" ? allowed_topic.id : allowed_post.id
        property = { "reference" => { "type" => property_type } }
        definitions = {}
        overrides = {}
        expected = {}
        %w[top_level nested].each do |location|
          schema =
            if location == "top_level"
              { "name" => "references", "properties" => property }
            else
              {
                "name" => "sections",
                "properties" => {
                  "children" => {
                    "type" => "objects",
                    "schema" => {
                      "name" => "references",
                      "properties" => property,
                    },
                  },
                },
              }
            end
          allowed = [{ "reference" => allowed_id }]
          restricted = [{ "reference" => restricted_id }]
          if location == "nested"
            allowed = [{ "children" => allowed }]
            restricted = [{ "children" => restricted }]
          end
          %w[value default].each do |field|
            name = "#{location}_restricted_#{field}"
            default = field == "default" ? restricted : allowed
            value = field == "value" ? restricted : allowed
            definitions[name] = { "type" => "objects", "schema" => schema, "default" => default }
            overrides[name] = value
            expected[name] = { "value" => value, "default" => default }
          end
          definitions["#{location}_allowed"] = {
            "type" => "objects",
            "schema" => schema,
            "default" => allowed,
          }
          expected["#{location}_allowed"] = { "value" => allowed, "default" => allowed }
        end
        theme = Fabricate(:theme)
        theme.set_field(
          target: :settings,
          name: :yaml,
          value: JSON.parse(definitions.to_json).to_yaml,
        )
        theme.save!
        overrides.each { |name, value| theme.update_setting(name, value) }
        baseline = rpc("discourse_get_theme", "theme_id" => theme.id)
        expect_usable(baseline)
        payloads(baseline).each do |payload|
          settings =
            payload.fetch("theme").fetch("settings").index_by { |row| row.fetch("setting") }
          expected.each { |name, values| expect(settings.fetch(name)).to include(values) }
        end
        if rule_kind == "private_messages"
          McpContentRule.create!(rule_kind:, config: {})
        else
          forum_rule(denied_categories: [denied_category.id])
        end
        expect(McpContentRule.pluck(:rule_kind)).to eq([rule_kind])

        response = rpc("discourse_get_theme", "theme_id" => theme.id)
        expect_usable(response)

        aggregate_failures do
          payloads(response).each_with_index do |payload, index|
            settings = payload.fetch("theme").fetch("settings")
            settings.each do |setting|
              expect_absent(
                setting.slice("value", "default"),
                [restricted_id],
                "#{property_type} #{rule_kind} #{setting.fetch("setting")} payload #{index}",
              )
            end
            expected.each do |name, values|
              next if !name.end_with?("_allowed")
              expect(settings.find { |setting| setting["setting"] == name }).to include(values)
            end
          end
        end
      end
    end

    include_examples "typed content references", "topic", "forum_content"
    include_examples "typed content references", "post", "forum_content"
    include_examples "typed content references", "topic", "private_messages"
    include_examples "typed content references", "post", "private_messages"
  end
end
