# frozen_string_literal: true

require_relative "read_tool_support"

describe DiscourseMcp::Server, "#call" do
  include McpContentReadHelpers

  # Only the exact caller query echo is exempt from response equality.
  def without_query_echo(response, query)
    response = response.deep_dup
    result = response.fetch("body").fetch("result")
    structured = result.fetch("structuredContent")
    structured["meta"]["term"] = "<caller query>" if structured.dig("meta", "term") == query
    result
      .fetch("content")
      .each do |part|
        next unless part["type"] == "text"
        text = part.fetch("text")
        next unless JSON.parse(text).dig("meta", "term") == query
        pattern = /("term"\s*:\s*)#{Regexp.escape(JSON.generate(query))}/
        expect(text.scan(pattern).length).to eq(1)
        part["text"] = text.sub(pattern) do
          "#{Regexp.last_match(1)}#{JSON.generate("<caller query>")}"
        end
      end
    response
  end

  shared_examples "restricted topic search selectors" do |tool, restriction|
    it "#{tool} treats #{restriction} topic selectors like missing topics and scopes allowed topics" do
      allowed_category = Fabricate(:category, id: 121_840_001)
      restricted_category = Fabricate(:category, id: 121_840_002)
      restricted_topic =
        if restriction == :pm_off
          Fabricate(:private_message_topic, id: 121_840_101, user: admin)
        else
          Fabricate(:topic, id: 121_840_101, user: admin, category: restricted_category)
        end
      allowed_topic = Fabricate(:topic, id: 121_840_102, user: admin, category: allowed_category)
      outside_topic = Fabricate(:topic, id: 121_840_103, user: admin, category: allowed_category)
      posts =
        [restricted_topic, allowed_topic, outside_topic].each_with_index.map do |topic, index|
          Fabricate(
            :post,
            id: 121_840_201 + index,
            user: admin,
            topic:,
            raw: "crfinalneedle searchable evidence for seasonal gardens #{index}",
          )
        end
      SearchIndexer.with_indexing { posts.each { |post| SearchIndexer.index(post, force: true) } }
      missing_id = 121_840_199
      expect(Topic.with_deleted.exists?(id: missing_id)).to eq(false)
      rows_key = tool == "discourse_search" ? "results" : "topics"

      calibration = rpc(tool, "query" => "topic:#{restricted_topic.id} crfinalneedle")
      expect_usable(calibration)
      payloads(calibration).each do |payload|
        expect(payload.fetch(rows_key).pluck("id")).to eq([restricted_topic.id])
      end
      if restriction == :pm_off
        McpContentRule.create!(rule_kind: "private_messages", config: {})
      else
        forum_rule(denied_categories: [restricted_category.id])
      end

      unscoped = rpc(tool, "query" => "crfinalneedle")
      expect_usable(unscoped)
      payloads(unscoped).each do |payload|
        expect(payload.fetch(rows_key).pluck("id")).to contain_exactly(
          allowed_topic.id,
          outside_topic.id,
        )
      end

      aggregate_failures("#{tool} #{restriction}") do
        ["", " order:latest"].each do |order|
          allowed = rpc(tool, "query" => "topic:#{allowed_topic.id} crfinalneedle#{order}")
          expect_usable(allowed)
          payloads(allowed).each do |payload|
            expect(payload.fetch(rows_key).pluck("id")).to eq([allowed_topic.id])
            if tool == "discourse_search_posts"
              expect(payload.fetch("posts").pluck("topic_id")).to eq([allowed_topic.id])
            end
          end

          restricted_query = "topic:#{restricted_topic.id} crfinalneedle#{order}"
          missing_query = "topic:#{missing_id} crfinalneedle#{order}"
          hidden = rpc(tool, "query" => restricted_query)
          missing = rpc(tool, "query" => missing_query)
          expect_usable(hidden)
          expect_usable(missing)
          expect(
            without_query_echo(hidden, restricted_query) ==
              without_query_echo(missing, missing_query),
          ).to eq(true),
          "#{tool} #{restriction}#{order}: restricted ids=#{payloads(hidden).first.fetch(rows_key).pluck("id").inspect}; missing ids=#{payloads(missing).first.fetch(rows_key).pluck("id").inspect}"
        end
      end
    end
  end

  include_examples "restricted topic search selectors", "discourse_search", :forum_rule
  include_examples "restricted topic search selectors", "discourse_search", :pm_off
  include_examples "restricted topic search selectors", "discourse_search_posts", :forum_rule
  include_examples "restricted topic search selectors", "discourse_search_posts", :pm_off
end
