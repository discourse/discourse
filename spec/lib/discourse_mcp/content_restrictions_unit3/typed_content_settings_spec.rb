# frozen_string_literal: true

require_relative "server_support"

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  shared_examples "typed content references" do |property_type, rule_kind|
    it "[cr-u3] GetTheme conceals top-level and nested #{property_type} values and defaults under #{rule_kind}" do
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
        settings = payload.fetch("theme").fetch("settings").index_by { |row| row.fetch("setting") }
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
