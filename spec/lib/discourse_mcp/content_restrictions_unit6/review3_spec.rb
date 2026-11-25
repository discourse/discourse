# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Admin::McpController, type: :request, aggregate_failures: true do
  include_context "with unit six request registry"

  describe "#update_content_restriction" do
    before { sign_in(admin) }

    %w[allow deny].each do |side|
      it "[cr-u6] applies #{side} synonym ids to topics carrying the canonical tag" do
        canonical = Fabricate(:tag, id: 114_620_051, name: "u6r3-canonical")
        synonym = Fabricate(:tag, id: 114_620_052, name: "u6r3-synonym", target_tag: canonical)
        tagged = Fabricate(:topic, id: 114_620_053, tags: [canonical])
        other = Fabricate(:topic, id: 114_620_054)
        config = forum_config
        config[side]["tag_ids"] = [synonym.id]
        config["allow"]["mode"] = "selected" if side == "allow"

        put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

        expect(response.status).to eq(200)
        expect(McpContentRule.find_by!(rule_kind: "forum_content")).to be_persisted
        visible =
          DiscourseMcp::ContentPolicy.load.scope_topics(Topic.where(id: [tagged.id, other.id]))
        expect(visible.pluck(:id)).to eq([side == "allow" ? tagged.id : other.id])
      end

      it "[cr-u6] controls #{side} ordinary ids and refuses missing ids on create and replace" do
        tag = Fabricate(:tag, id: 114_620_061, name: "u6r3-ordinary")
        tagged = Fabricate(:topic, id: 114_620_063, tags: [tag])
        other = Fabricate(:topic, id: 114_620_064)
        config = forum_config
        config[side]["tag_ids"] = [tag.id]
        config["allow"]["mode"] = "selected" if side == "allow"

        put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

        expect(response.status).to eq(200)
        expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(config)
        visible =
          DiscourseMcp::ContentPolicy.load.scope_topics(Topic.where(id: [tagged.id, other.id]))
        expect(visible.pluck(:id)).to eq([side == "allow" ? tagged.id : other.id])
        expect(Tag.exists?(114_620_099)).to eq(false)
        bad = config.deep_dup
        bad[side]["tag_ids"] = [114_620_099]

        [true, false].each do |replacing|
          McpContentRule.delete_all if !replacing
          before_rows = McpContentRule.order(:id).map(&:attributes)
          before_logs = UserHistory.order(:id).pluck(:id)

          put "/admin/mcp/content-restrictions/forum_content.json",
              params: {
                config: bad,
              },
              as: :json

          aggregate_failures("#{replacing ? "replace" : "create"} missing-id refusal") do
            expect(response.status).to be_between(400, 499)
            expect(response.parsed_body["errors"]).to be_present
            expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
            expect(UserHistory.order(:id).pluck(:id)).to eq(before_logs)
          end
        end
      end

      { "null only" => [nil], "known name then null" => ["u6r3-known", nil] }.each do |shape, names|
        %w[create replace].each do |operation|
          it "[cr-u6] refuses raw JSON #{side} #{shape} on #{operation} without storage or logs" do
            Fabricate(:tag, id: 114_620_071, name: "u6r3-known")
            retained = Fabricate(:tag, id: 114_620_072, name: "u6r3-retained")
            previous = forum_config
            previous[side]["tag_ids"] = [retained.id]
            previous["allow"]["mode"] = "selected" if side == "allow"
            if operation == "replace"
              put "/admin/mcp/content-restrictions/forum_content.json",
                  params: {
                    config: previous,
                  },
                  as: :json
              expect(response.status).to eq(200)
              expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
            end
            bad = forum_config
            bad["allow"]["mode"] = "selected" if side == "allow"
            bad[side].delete("tag_ids")
            bad[side]["tag_names"] = names
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

      it "[cr-u6] saves raw JSON #{side} empty names and clears an existing tag list" do
        tag = Fabricate(:tag, id: 114_620_081, name: "u6r3-clear")
        config = forum_config
        config["allow"]["mode"] = "selected" if side == "allow"
        config[side].delete("tag_ids")
        config[side]["tag_names"] = []

        [false, true].each do |replacing|
          if replacing
            previous = forum_config
            previous[side]["tag_ids"] = [tag.id]
            previous["allow"]["mode"] = "selected" if side == "allow"
            put "/admin/mcp/content-restrictions/forum_content.json",
                params: {
                  config: previous,
                },
                as: :json
            expect(response.status).to eq(200)
            expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
          end

          put "/admin/mcp/content-restrictions/forum_content.json",
              params: { config: }.to_json,
              headers: {
                "CONTENT_TYPE" => "application/json",
              }

          expect(response.status).to eq(200)
          expected = forum_config
          expected["allow"]["mode"] = "selected" if side == "allow"
          expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(expected)
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
