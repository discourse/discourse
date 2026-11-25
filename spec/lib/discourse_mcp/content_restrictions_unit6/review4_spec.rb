# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Admin::McpController, type: :request, aggregate_failures: true do
  include_context "with unit six request registry"

  describe "#update_content_restriction" do
    before { sign_in(admin) }

    %w[allow deny].each do |side|
      %w[tag_ids category_ids].each do |field|
        [
          "whole float",
          "mixed integer and whole float",
          "fractional float",
          "string",
          "null",
          "true",
          "false",
          "object",
          "array",
        ].each do |shape|
          %w[create replace].each do |operation|
            it "[cr-u6] refuses raw JSON #{side}.#{field} #{shape} on #{operation} without storage or logs" do
              if field == "tag_ids"
                canonical = Fabricate(:tag, id: 114_620_101, name: "u6r4-canonical")
                first =
                  Fabricate(:tag, id: 114_620_102, name: "u6r4-synonym", target_tag: canonical)
                second = Fabricate(:tag, id: 114_620_103, name: "u6r4-ordinary")
              else
                first = Fabricate(:category, id: 114_620_111)
                second = Fabricate(:category, id: 114_620_112)
              end
              if operation == "replace"
                retained = Fabricate(:tag, id: 114_620_104, name: "u6r4-retained")
                previous = forum_config
                previous["deny"]["tag_ids"] = [retained.id]

                put "/admin/mcp/content-restrictions/forum_content.json",
                    params: { config: previous }.to_json,
                    headers: {
                      "CONTENT_TYPE" => "application/json",
                    }

                expect(response.status).to eq(200)
                expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
              end
              bad = forum_config
              bad["allow"]["mode"] = "selected" if side == "allow"
              bad[side][field] = case shape
              when "whole float"
                [first.id.to_f]
              when "mixed integer and whole float"
                [first.id, second.id.to_f]
              when "fractional float"
                [first.id + 0.5]
              when "string"
                [first.id.to_s]
              when "null"
                [nil]
              when "true"
                [true]
              when "false"
                [false]
              when "object"
                [{ "id" => first.id }]
              when "array"
                [[first.id]]
              end
              before_rows = McpContentRule.order(:id).map(&:attributes)
              before_logs = UserHistory.order(:id).pluck(:id)

              put "/admin/mcp/content-restrictions/forum_content.json",
                  params: { config: bad }.to_json,
                  headers: {
                    "CONTENT_TYPE" => "application/json",
                  }

              expect(response.status).to eq(400)
              expect(response.parsed_body["errors"]).to be_present
              expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
              expect(UserHistory.order(:id).pluck(:id)).to eq(before_logs)
            end
          end
        end

        it "[cr-u6] saves raw JSON integer #{side}.#{field} on create and replace with topic visibility" do
          if field == "tag_ids"
            first = Fabricate(:tag, id: 114_620_101, name: "u6r4-canonical")
            second = Fabricate(:tag, id: 114_620_103, name: "u6r4-ordinary")
            matched = Fabricate(:topic, id: 114_620_121, tags: [first])
            another = Fabricate(:topic, id: 114_620_122, tags: [second])
          else
            first = Fabricate(:category, id: 114_620_111)
            second = Fabricate(:category, id: 114_620_112)
            matched = Fabricate(:topic, id: 114_620_121, category: first)
            another = Fabricate(:topic, id: 114_620_122, category: second)
          end
          other = Fabricate(:topic, id: 114_620_123)
          retained = Fabricate(:tag, id: 114_620_104, name: "u6r4-retained")
          config = forum_config
          config["allow"]["mode"] = "selected" if side == "allow"
          config[side][field] = [first.id, second.id]

          %w[create replace].each do |operation|
            if operation == "replace"
              previous = forum_config
              previous["deny"]["tag_ids"] = [retained.id]
              put "/admin/mcp/content-restrictions/forum_content.json",
                  params: { config: previous }.to_json,
                  headers: {
                    "CONTENT_TYPE" => "application/json",
                  }
              expect(response.status).to eq(200)
              expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
            end
            before_logs = UserHistory.order(:id).pluck(:id)

            put "/admin/mcp/content-restrictions/forum_content.json",
                params: { config: }.to_json,
                headers: {
                  "CONTENT_TYPE" => "application/json",
                }

            aggregate_failures(operation) do
              expect(response.status).to eq(200)
              expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(config)
              expect(UserHistory.order(:id).pluck(:id).size).to eq(before_logs.size + 1)
              visible =
                DiscourseMcp::ContentPolicy.load.scope_topics(
                  Topic.where(id: [matched.id, another.id, other.id]),
                )
              expect(visible.pluck(:id)).to contain_exactly(
                *(side == "allow" ? [matched.id, another.id] : [other.id]),
              )
            end
          end
        end
      end
    end
  end

  describe "stored forum_content topic visibility" do
    %w[allow deny].each do |side|
      it "[cr-u6] applies directly stored #{side} synonym ids to topics carrying the target tag" do
        canonical = Fabricate(:tag, id: 114_620_101, name: "u6r4-canonical")
        synonym = Fabricate(:tag, id: 114_620_102, name: "u6r4-synonym", target_tag: canonical)
        ordinary = Fabricate(:tag, id: 114_620_103, name: "u6r4-ordinary")
        tagged = Fabricate(:topic, id: 114_620_121, tags: [canonical])
        another = Fabricate(:topic, id: 114_620_122, tags: [ordinary])
        other = Fabricate(:topic, id: 114_620_123)
        config = forum_config
        config["allow"]["mode"] = "selected" if side == "allow"
        config[side]["tag_ids"] = [synonym.id, ordinary.id]
        row =
          McpContentRule.create!(
            rule_kind: "forum_content",
            config: forum_config,
            updated_by: admin,
          )
        row.update_columns(config: config)

        expect(row.reload.config).to eq(config)
        visible =
          DiscourseMcp::ContentPolicy.load.scope_topics(
            Topic.where(id: [tagged.id, another.id, other.id]),
          )

        expect(visible.pluck(:id)).to contain_exactly(
          *(side == "allow" ? [tagged.id, another.id] : [other.id]),
        )
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
