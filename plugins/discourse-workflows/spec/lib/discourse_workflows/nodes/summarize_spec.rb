# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Summarize::V1 do
  def execute(input_items, configuration = {})
    execute_node_output(configuration: configuration, input_items: input_items).first
  end

  def aggregations(*rows)
    { "values" => rows }
  end

  def json(result)
    result.map { |item| item["json"] }
  end

  let(:posts) do
    [
      { "json" => { "id" => 1, "topic_id" => 7, "username" => "ann", "likes" => 9 } },
      { "json" => { "id" => 2, "topic_id" => 7, "username" => "bob", "likes" => 3 } },
      { "json" => { "id" => 3, "topic_id" => 8, "username" => "ann", "likes" => 4 } },
    ]
  end

  describe "without a group key" do
    it "collapses every item into a single summary item" do
      result =
        execute(
          posts,
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "count", "output_field_name" => "returned_posts" },
              {
                "aggregation" => "count_unique",
                "field" => "topic_id",
                "output_field_name" => "returned_topics",
              },
              { "aggregation" => "sum", "field" => "likes", "output_field_name" => "total_likes" },
            ),
        )

      expect(result.length).to eq(1)
      expect(json(result).first).to eq(
        { "returned_posts" => 3, "returned_topics" => 2, "total_likes" => 16 },
      )
    end

    it "derives output field names from the aggregation and field" do
      result =
        execute(
          posts,
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "sum", "field" => "likes" },
              { "aggregation" => "count" },
            ),
        )

      expect(json(result).first).to eq({ "sum_likes" => 16, "count" => 3 })
    end
  end

  describe "grouping" do
    it "emits one item per group with the group key alongside the aggregates" do
      result =
        execute(
          posts,
          "fields_to_split_by" => "username",
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "sum", "field" => "likes", "output_field_name" => "likes" },
              { "aggregation" => "count", "output_field_name" => "posts" },
            ),
        )

      expect(json(result)).to eq(
        [
          { "username" => "ann", "likes" => 13, "posts" => 2 },
          { "username" => "bob", "likes" => 3, "posts" => 1 },
        ],
      )
    end

    it "groups by several fields at once" do
      result =
        execute(
          posts,
          "fields_to_split_by" => "topic_id, username",
          "fields_to_summarize" => aggregations({ "aggregation" => "count" }),
        )

      expect(json(result)).to eq(
        [
          { "topic_id" => 7, "username" => "ann", "count" => 1 },
          { "topic_id" => 7, "username" => "bob", "count" => 1 },
          { "topic_id" => 8, "username" => "ann", "count" => 1 },
        ],
      )
    end

    it "writes dotted group keys under their leaf name" do
      input = [{ "json" => { "post" => { "topic_id" => 7 } } }]
      result =
        execute(
          input,
          "fields_to_split_by" => "post.topic_id",
          "fields_to_summarize" => aggregations({ "aggregation" => "count" }),
        )

      expect(json(result)).to eq([{ "topic_id" => 7, "count" => 1 }])
    end
  end

  describe "collect" do
    it "nests each group's items under the output field" do
      result =
        execute(
          posts,
          "fields_to_split_by" => "topic_id",
          "fields_to_summarize" =>
            aggregations({ "aggregation" => "collect", "output_field_name" => "posts" }),
        )

      expect(json(result).first["posts"].map { |post| post["id"] }).to eq([1, 2])
      expect(json(result).last["posts"].map { |post| post["id"] }).to eq([3])
    end

    it "collects a single field when one is given" do
      result =
        execute(
          posts,
          "fields_to_split_by" => "topic_id",
          "fields_to_summarize" => aggregations({ "aggregation" => "collect", "field" => "id" }),
        )

      expect(json(result).first["collected_id"]).to eq([1, 2])
    end
  end

  describe "unique" do
    it "flattens array values and removes duplicates" do
      input = [
        { "json" => { "topic_id" => 7, "tags" => %w[perf bug] } },
        { "json" => { "topic_id" => 7, "tags" => %w[bug ux] } },
      ]
      result =
        execute(
          input,
          "fields_to_split_by" => "topic_id",
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "unique", "field" => "tags", "output_field_name" => "tags" },
            ),
        )

      expect(json(result).first["tags"]).to eq(%w[perf bug ux])
    end

    it "counts distinct values without returning them" do
      input = [{ "json" => { "tags" => %w[perf bug] } }, { "json" => { "tags" => %w[bug ux] } }]
      result =
        execute(
          input,
          "fields_to_summarize" =>
            aggregations({ "aggregation" => "count_unique", "field" => "tags" }),
        )

      expect(json(result).first["unique_count_tags"]).to eq(3)
    end
  end

  describe "first and last" do
    it "carries a per-group invariant without repeating it" do
      input = [
        { "json" => { "topic_id" => 7, "title" => "Ember upgrade" } },
        { "json" => { "topic_id" => 7, "title" => "Ember upgrade" } },
      ]
      result =
        execute(
          input,
          "fields_to_split_by" => "topic_id",
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "first", "field" => "title", "output_field_name" => "title" },
            ),
        )

      expect(json(result).first["title"]).to eq("Ember upgrade")
    end

    it "skips empty values so a missing first value does not win" do
      input = [{ "json" => { "title" => nil } }, { "json" => { "title" => "Real title" } }]
      result =
        execute(
          input,
          "fields_to_summarize" => aggregations({ "aggregation" => "first", "field" => "title" }),
        )

      expect(json(result).first["first_title"]).to eq("Real title")
    end
  end

  describe "numeric aggregations" do
    it "computes average, min, and max" do
      result =
        execute(
          posts,
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "average", "field" => "likes" },
              { "aggregation" => "min", "field" => "likes" },
              { "aggregation" => "max", "field" => "likes" },
            ),
        )

      expect(json(result).first).to eq(
        { "average_likes" => 16 / 3.0, "min_likes" => 3, "max_likes" => 9 },
      )
    end

    it "coerces numeric strings" do
      input = [{ "json" => { "likes" => "4" } }, { "json" => { "likes" => "6" } }]
      result =
        execute(
          input,
          "fields_to_summarize" => aggregations({ "aggregation" => "sum", "field" => "likes" }),
        )

      expect(json(result).first["sum_likes"]).to eq(10.0)
    end

    it "returns nil for an average with no numeric values" do
      input = [{ "json" => { "likes" => nil } }]
      result =
        execute(
          input,
          "fields_to_summarize" => aggregations({ "aggregation" => "average", "field" => "likes" }),
        )

      expect(json(result).first["average_likes"]).to be_nil
    end
  end

  describe "concatenate" do
    it "joins values with the configured separator" do
      result =
        execute(
          posts,
          "fields_to_summarize" =>
            aggregations(
              {
                "aggregation" => "concatenate",
                "field" => "username",
                "separate_by" => "comma_space",
              },
            ),
        )

      expect(json(result).first["concatenated_username"]).to eq("ann, bob, ann")
    end

    it "supports a custom separator" do
      result =
        execute(
          posts,
          "fields_to_summarize" =>
            aggregations(
              {
                "aggregation" => "concatenate",
                "field" => "username",
                "separate_by" => "custom",
                "custom_separator" => " | ",
              },
            ),
        )

      expect(json(result).first["concatenated_username"]).to eq("ann | bob | ann")
    end
  end

  describe "append" do
    it "keeps duplicates and does not flatten arrays" do
      input = [{ "json" => { "tags" => %w[perf bug] } }, { "json" => { "tags" => %w[bug] } }]
      result =
        execute(
          input,
          "fields_to_summarize" => aggregations({ "aggregation" => "append", "field" => "tags" }),
        )

      expect(json(result).first["appended_tags"]).to eq([%w[perf bug], %w[bug]])
    end

    it "skips empty values by default" do
      input = [{ "json" => { "name" => "ann" } }, { "json" => { "name" => "" } }]
      result =
        execute(
          input,
          "fields_to_summarize" => aggregations({ "aggregation" => "append", "field" => "name" }),
        )

      expect(json(result).first["appended_name"]).to eq(["ann"])
    end
  end

  describe "validation" do
    it "fails when no aggregation is configured" do
      expect { execute(posts, "fields_to_summarize" => aggregations) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /No aggregations configured/,
      )
    end

    it "fails on an unknown aggregation" do
      expect {
        execute(posts, "fields_to_summarize" => aggregations({ "aggregation" => "median" }))
      }.to raise_error(DiscourseWorkflows::NodeError, /Unknown aggregation: median/)
    end

    it "fails when two aggregations write to the same field" do
      expect {
        execute(
          posts,
          "fields_to_summarize" =>
            aggregations(
              { "aggregation" => "sum", "field" => "likes", "output_field_name" => "total" },
              { "aggregation" => "count", "output_field_name" => "total" },
            ),
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /same output field 'total'/)
    end
  end

  describe ".output_schemas" do
    it "names the editor-side resolver so both sides derive the same keys" do
      expect(described_class.output_schema_resolver).to eq("summarize")
    end

    it "derives properties from the configured aggregations and group keys" do
      schema =
        described_class.output_schemas(
          {
            "fields_to_split_by" => "topic_id",
            "fields_to_summarize" => {
              "values" => [
                { "aggregation" => "sum", "field" => "likes", "output_field_name" => "post_likes" },
                { "aggregation" => "count" },
              ],
            },
          },
        ).first

      expect(schema["properties"].keys).to eq(%w[topic_id post_likes count])
      expect(schema.dig("properties", "count", "type")).to eq("integer")
    end
  end
end
