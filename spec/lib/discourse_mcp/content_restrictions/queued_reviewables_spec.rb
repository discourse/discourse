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

  def expect_queued_post_concealed(reviewable, empty_responses, missing_id:)
    expect(reviewable.topic_id).to be_nil
    expect(Reviewable.exists?(id: missing_id)).to eq(false)

    aggregate_failures do
      empty_responses.each do |tool, empty|
        response = rpc(tool, {})
        expect_usable(response)
        data = payloads(response).first
        expect(JSON.generate(response)).to eq(JSON.generate(empty)),
        "#{tool}: expected the queue response with this queued post absent; ids=#{data["reviewables"]&.pluck("id").inspect}; count=#{data["count"].inspect}"
      end

      [false, true].each do |explanation|
        arguments = { "include_explanation" => explanation }
        missing = rpc("discourse_get_reviewable", arguments.merge("reviewable_id" => missing_id))
        expect(missing.dig("body", "result", "isError")).to eq(true)
        response =
          rpc("discourse_get_reviewable", arguments.merge("reviewable_id" => reviewable.id))
        expect(JSON.generate(response)).to eq(JSON.generate(missing)),
        "discourse_get_reviewable explanation=#{explanation}: expected missing-reviewable envelope"
      end

      %w[approve_post reject_post delete].each do |action|
        arguments = { "action_id" => action, "confirm" => true }
        missing =
          rpc("discourse_perform_reviewable_action", arguments.merge("reviewable_id" => missing_id))
        expect(missing.dig("body", "result", "isError")).to eq(true)
        ActiveRecord::Base.transaction(requires_new: true) do
          before_state = reviewable.reload.attributes
          response =
            rpc(
              "discourse_perform_reviewable_action",
              arguments.merge("reviewable_id" => reviewable.id),
            )
          expect(JSON.generate(response)).to eq(JSON.generate(missing)),
          "discourse_perform_reviewable_action #{action}: expected missing-reviewable envelope"
          expect(reviewable.reload.attributes).to eq(before_state),
          "discourse_perform_reviewable_action #{action}: concealed queued post changed"
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  shared_examples "existing long queued tags" do |shape|
    it "conceals an existing over-length restricted tag supplied as #{shape}" do
      SiteSetting.max_tag_length = 60
      category = Fabricate(:category, id: 122_850_001)
      denied_tag = Fabricate(:tag, id: 122_850_011, name: "seasonalgardensrestricted")
      SiteSetting.max_tag_length = 10
      expect(denied_tag.reload.name.length).to be > SiteSetting.max_tag_length
      expect(Tag.exists?(name: denied_tag.name.first(SiteSetting.max_tag_length))).to eq(false)
      forum_rule(denied_tags: [denied_tag.id])
      empty_responses =
        %w[discourse_list_reviewables discourse_get_review_queue_count].index_with do |tool|
          rpc(tool, {}).tap { |response| expect_usable(response) }
        end
      name = shape.to_s.start_with?("uppercase") ? denied_tag.name.upcase : denied_tag.name
      entry = shape.to_s.end_with?("object") ? { "name" => name } : name
      reviewable =
        Fabricate(
          :reviewable_queued_post_topic,
          id: 122_850_021,
          category:,
          target_created_by: admin,
          score: 999,
          payload: {
            "raw" => "A queued discussion about seasonal gardens.",
            "title" => "Seasonal garden observations",
            "archetype" => "regular",
            "tags" => [entry],
          },
        )

      expect_queued_post_concealed(reviewable, empty_responses, missing_id: 122_850_099)
    end
  end

  include_examples "existing long queued tags", :lowercase_string
  include_examples "existing long queued tags", :uppercase_string
  include_examples "existing long queued tags", :lowercase_object
  include_examples "existing long queued tags", :uppercase_object

  shared_examples "queued payload category restrictions" do |shape|
    it "conceals a topicless queued post with #{shape} payload category and keeps an allowed category" do
      allowed_category = Fabricate(:category, id: 122_860_001)
      denied_category = Fabricate(:category, id: 122_860_002)
      forum_rule(denied_categories: [denied_category.id])
      control =
        Fabricate(
          :reviewable_queued_post_topic,
          id: 122_860_021,
          category: nil,
          target_created_by: admin,
          score: 999,
          payload: {
            "raw" => "A queued discussion about seasonal gardens.",
            "title" => "Seasonal garden observations",
            "archetype" => "regular",
            "category" => allowed_category.id,
            "tags" => [],
          },
        )
      expect(control.reload.category_id).to be_nil
      empty_responses =
        %w[discourse_list_reviewables discourse_get_review_queue_count].index_with do |tool|
          rpc(tool, {}).tap { |response| expect_usable(response) }
        end
      payloads(empty_responses.fetch("discourse_list_reviewables")).each do |payload|
        expect(payload.fetch("reviewables").pluck("id")).to eq([control.id])
      end
      payloads(empty_responses.fetch("discourse_get_review_queue_count")).each do |payload|
        expect(payload.fetch("count")).to eq(1)
      end
      category =
        case shape
        when :integer
          denied_category.id
        when :numeric_string
          denied_category.id.to_s
        when :nonnumeric_string
          "abc"
        end
      reviewable =
        Fabricate(
          :reviewable_queued_post_topic,
          id: 122_860_022,
          category: nil,
          target_created_by: admin,
          score: 999,
          payload: control.payload.merge("category" => category),
        )
      expect(reviewable.reload.category_id).to be_nil

      expect_queued_post_concealed(reviewable, empty_responses, missing_id: 122_860_099)
    end
  end

  include_examples "queued payload category restrictions", :integer
  include_examples "queued payload category restrictions", :numeric_string
  include_examples "queued payload category restrictions", :nonnumeric_string

  shared_examples "bounded queued payload reads" do |tool|
    it "loads the same number of queued payload rows for #{tool} after unrelated history grows" do
      category = Fabricate(:category, id: 122_870_001)
      denied_tag = Fabricate(:tag, id: 122_870_011, name: "seasonaldenied")
      allowed_tag = Fabricate(:tag, id: 122_870_012, name: "seasonalallowed")
      forum_rule(denied_tags: [denied_tag.id])
      topic = Fabricate(:topic, category:) if tool == "discourse_list_reviewable_topics"
      reviewable =
        Fabricate(
          :reviewable_queued_post_topic,
          id: 122_870_021,
          category:,
          topic:,
          created_by: admin,
          target_created_by: admin,
          score: 999,
          payload: {
            "raw" => "A queued discussion about seasonal gardens.",
            "title" => "Seasonal garden observations",
            "archetype" => "regular",
            "tags" => [allowed_tag.name],
          },
        )
      arguments = tool == "discourse_get_reviewable" ? { "reviewable_id" => reviewable.id } : {}
      access_token
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: tool).update!(enabled: true)
      loads = []
      subscriber = ->(*, event) do
        sql = event.fetch(:sql).delete('"')
        projection = sql[/\ASELECT\s+(.*?)\s+FROM\s+reviewables\b/im, 1]
        if projection&.match?(/\bpayload\b|(?:\A|,\s*|\breviewables\.)\*/i)
          loads << { rows: event.fetch(:row_count), sql: }
        end
      end
      response = nil
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
          response = rpc(tool, arguments)
        end
      end
      expect_usable(response)
      expected_key =
        case tool
        when "discourse_get_reviewable"
          "reviewable"
        when "discourse_list_reviewable_topics"
          "topics"
        else
          "reviewables"
        end
      expected_ids = [topic ? topic.id : reviewable.id]
      payloads(response).each do |payload|
        rows = Array.wrap(payload.fetch(expected_key))
        expect(rows.pluck("id")).to eq(expected_ids)
      end
      baseline_rows = loads.sum { |load| load.fetch(:rows) }
      if topic
        expect(baseline_rows).to eq(0)
      else
        expect(baseline_rows).to be > 0
      end
      historical_tags = ["#{denied_tag.name}!"]
      expect(DiscourseTagging.clean_tag(historical_tags.first)).to eq(denied_tag.name)
      30.times do |index|
        Fabricate(
          :reviewable_queued_post_topic,
          id: 122_870_100 + index,
          category:,
          topic: nil,
          created_by: admin,
          target_created_by: admin,
          status: %i[approved rejected deleted][index % 3],
          payload: reviewable.payload.merge("tags" => historical_tags),
        )
      end
      loads.clear
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
          response = rpc(tool, arguments)
        end
      end
      expect_usable(response)
      payloads(response).each do |payload|
        expect(Array.wrap(payload.fetch(expected_key)).pluck("id")).to eq(expected_ids)
      end
      loaded_rows = loads.sum { |load| load.fetch(:rows) }
      expect(loaded_rows).to eq(baseline_rows),
      "#{tool}: expected #{baseline_rows} payload rows loaded, got #{loaded_rows} after unrelated queue history grew: #{loads.inspect}"
    end
  end

  include_examples "bounded queued payload reads", "discourse_get_reviewable"
  include_examples "bounded queued payload reads", "discourse_list_reviewables"
  include_examples "bounded queued payload reads", "discourse_list_reviewable_topics"
end
