# frozen_string_literal: true

require_relative "read_tool_support"

describe DiscourseMcp::Server, "#call" do
  include McpContentReadHelpers

  shared_examples "queued tag payload restrictions" do |shape|
    it "conceals a new queued topic with #{shape} tags and keeps allowed tag objects" do
      category = Fabricate(:category, id: 121_840_001)
      denied_tag = Fabricate(:tag, id: 121_840_011, name: "crfinaldenied")
      allowed_tag = Fabricate(:tag, id: 121_840_012, name: "crfinalallowed")
      missing_id = 121_840_099
      expect(Reviewable.exists?(id: missing_id)).to eq(false)
      forum_rule(denied_tags: [denied_tag.id])

      empty_responses =
        %w[
          discourse_list_reviewables
          discourse_get_review_queue_count
          discourse_list_reviewable_topics
        ].index_with { |tool| rpc(tool, {}).tap { |response| expect_usable(response) } }
      reviewable =
        Fabricate(
          :reviewable_queued_post_topic,
          id: 121_840_021,
          category:,
          score: 999,
          payload: {
            "raw" => "A queued crfinal witness about seasonal gardens.",
            "title" => "A queued crfinal topic about seasonal gardens",
            "archetype" => "regular",
            "tags" => [{ "id" => allowed_tag.id, "name" => allowed_tag.name }],
          },
        )

      allowed = rpc("discourse_list_reviewables", {})
      expect_usable(allowed)
      payloads(allowed).each do |payload|
        expect(payload.fetch("reviewables").pluck("id")).to eq([reviewable.id])
      end
      [false, true].each do |explanation|
        allowed =
          rpc(
            "discourse_get_reviewable",
            "reviewable_id" => reviewable.id,
            "include_explanation" => explanation,
          )
        expect_usable(allowed)
        payloads(allowed).each do |payload|
          expect(payload.fetch("reviewable").fetch("id")).to eq(reviewable.id)
        end
      end
      allowed_count = rpc("discourse_get_review_queue_count", {})
      expect_usable(allowed_count)
      payloads(allowed_count).each { |payload| expect(payload.fetch("count")).to eq(1) }

      denied_object = { "id" => denied_tag.id, "name" => denied_tag.name }
      tags =
        case shape
        when :denied_object
          [denied_object]
        when :mixed_strings_and_object
          [allowed_tag.name, denied_object]
        when :object_without_name
          [{ "id" => allowed_tag.id }]
        when :number
          [allowed_tag.id]
        when :padded_name
          [" #{denied_tag.name} "]
        when :uppercase_name_object
          [{ "name" => denied_tag.name.upcase }]
        when :filtered_name
          ["#{denied_tag.name}!"]
        when :truncated_name
          SiteSetting.max_tag_length = denied_tag.name.length
          ["#{denied_tag.name}extended"]
        end
      reviewable.update!(payload: reviewable.payload.merge("tags" => tags))

      aggregate_failures("queued #{shape}") do
        empty_responses.each do |tool, empty|
          response = rpc(tool, {})
          expect_usable(response)
          data = payloads(response).first
          expect(response == empty).to eq(true),
          "queued #{shape} #{tool}: expected empty-queue response; ids=#{data["reviewables"]&.pluck("id").inspect}; count=#{data["count"].inspect}; meta=#{data["meta"].inspect}"
        end
        [false, true].each do |explanation|
          arguments = { "include_explanation" => explanation }
          missing = rpc("discourse_get_reviewable", arguments.merge("reviewable_id" => missing_id))
          expect(missing.dig("body", "result", "isError")).to eq(true)
          hidden =
            rpc("discourse_get_reviewable", arguments.merge("reviewable_id" => reviewable.id))
          expect(hidden == missing).to eq(true),
          "queued #{shape} get explanation=#{explanation}: expected missing-reviewable envelope, got isError=#{hidden.dig("body", "result", "isError").inspect}"
        end
      end
    end
  end

  include_examples "queued tag payload restrictions", :denied_object
  include_examples "queued tag payload restrictions", :mixed_strings_and_object
  include_examples "queued tag payload restrictions", :object_without_name
  include_examples "queued tag payload restrictions", :number
  include_examples "queued tag payload restrictions", :padded_name
  include_examples "queued tag payload restrictions", :uppercase_name_object
  include_examples "queued tag payload restrictions", :filtered_name
  include_examples "queued tag payload restrictions", :truncated_name
end
