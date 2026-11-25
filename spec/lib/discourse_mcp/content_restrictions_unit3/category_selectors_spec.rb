# frozen_string_literal: true

require_relative "server_support"

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  def selector_response(tool, query)
    field = tool == "discourse_filter_topics" ? "filter" : "query"
    response = rpc(tool, field => query)
    expect_usable(response)
    response
  end

  def result_ids(tool, response)
    data = payloads(response).first
    data
      .fetch(tool == "discourse_search_posts" ? "topics" : "results")
      .map { |row| row.fetch("id") }
  end

  # Only the caller's exact query echo is exempt, including its JSON text copy.
  def without_query_echo(response, query)
    response = response.deep_dup
    result = response.fetch("body").fetch("result")
    structured = result.fetch("structuredContent")
    structured["meta"]["term"] = "<caller query>" if structured.dig("meta", "term") == query
    result
      .fetch("content")
      .each do |part|
        next if part["type"] != "text"
        text = part.fetch("text")
        next if JSON.parse(text).dig("meta", "term") != query
        pattern = /("term"\s*:\s*)#{Regexp.escape(JSON.generate(query))}/
        expect(text.scan(pattern).length).to eq(1)
        part["text"] = text.sub(pattern) do
          "#{Regexp.last_match(1)}#{JSON.generate("<caller query>")}"
        end
      end
    response
  end

  shared_examples "restricted category selectors" do |tool, configuration|
    it "[cr-u3] #{tool} treats restricted category selectors like missing categories under #{configuration}" do
      category = Fabricate(:category_with_definition, user: admin, name: "cru3 selector category")
      outside = Fabricate(:category, user: admin)
      tag = Fabricate(:tag)
      inside_post =
        Fabricate(
          :post,
          user: admin,
          topic: Fabricate(:topic, user: admin, category:, title: "cru3needle inside topic"),
          raw: "cru3needle inside evidence",
        )
      outside_post =
        Fabricate(
          :post,
          user: admin,
          topic:
            Fabricate(:topic, user: admin, category: outside, title: "cru3needle outside topic"),
          raw: "cru3needle outside evidence",
        )
      SearchIndexer.with_indexing do
        [inside_post, outside_post].each { |post| SearchIndexer.index(post, force: true) }
      end
      missing = "cru3-missing-#{SecureRandom.hex(8)}"
      expect(Category.where(slug: missing).exists?).to eq(false)
      expect(Tag.where(name: missing).exists?).to eq(false)
      selectors =
        if tool == "discourse_filter_topics"
          %w[category:%s -category:%s =category:%s -=category:%s]
        else
          %w[category:%s -category:%s category:=%s #%s #=%s]
        end
      calibration = selector_response(tool, "cru3needle category:#{category.slug}")
      expect(result_ids(tool, calibration)).to include(inside_post.topic_id)
      if configuration == "denied_tag"
        category.topic.tags << tag
        forum_rule(denied_tags: [tag.id])
      else
        [inside_post, outside_post].each { |post| post.topic.tags << tag }
        forum_rule(selected_tags: [tag.id])
      end
      unfiltered =
        selector_response(tool, tool == "discourse_filter_topics" ? "order:latest" : "cru3needle")
      expect(result_ids(tool, unfiltered)).to include(inside_post.topic_id, outside_post.topic_id)
      hidden_category = rpc("discourse_get_category", "category_id" => category.id)
      absent_category = rpc("discourse_get_category", "category_id" => 99_999_999)
      expect(hidden_category).to eq(absent_category)
      expect(hidden_category.dig("body", "result", "isError")).to eq(true)

      aggregate_failures do
        selectors.each do |selector|
          restricted_query = "cru3needle #{selector % category.slug}"
          missing_query = "cru3needle #{selector % missing}"
          restricted = selector_response(tool, restricted_query)
          absent = selector_response(tool, missing_query)
          expect(without_query_echo(restricted, restricted_query)).to eq(
            without_query_echo(absent, missing_query),
          ),
          "#{tool} #{configuration} #{selector}: restricted category differs from missing category"
        end
      end
    end
  end

  include_examples "restricted category selectors", "discourse_filter_topics", "denied_tag"
  include_examples "restricted category selectors", "discourse_search", "denied_tag"
  include_examples "restricted category selectors", "discourse_search_posts", "denied_tag"
  include_examples "restricted category selectors",
                   "discourse_filter_topics",
                   "selected_allowlist_by_tag"
  include_examples "restricted category selectors", "discourse_search", "selected_allowlist_by_tag"
  include_examples "restricted category selectors",
                   "discourse_search_posts",
                   "selected_allowlist_by_tag"
end
