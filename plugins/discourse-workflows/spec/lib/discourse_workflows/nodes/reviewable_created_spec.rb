# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ReviewableCreated::V1 do
  fab!(:reviewable, :reviewable_flagged_post)

  describe ".property_schema" do
    it "includes reviewable type options for the multi-select control" do
      expect(described_class.property_schema.dig(:reviewable_types, :options)).to include(
        { value: "ReviewableFlaggedPost", label: "Reviewable flagged post" },
      )
    end
  end

  describe ".load_options_context" do
    it "returns reviewable types matching the filter" do
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "reviewable_types",
          filter: "flagged",
        )

      expect(described_class.load_options_context(context)).to contain_exactly(
        { id: "ReviewableFlaggedPost", name: "Reviewable flagged post" },
      )
    end
  end

  describe "#valid?" do
    it "returns true when a reviewable is present" do
      expect(described_class.new(reviewable)).to be_valid
    end

    it "returns false when the reviewable is missing" do
      expect(described_class.new(nil)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns reviewable data", :aggregate_failures do
      output = described_class.new(reviewable).output

      expect(output).to eq(
        reviewable: {
          id: reviewable.id,
          type: "ReviewableFlaggedPost",
          status: "pending",
          target_type: "Post",
          target_id: reviewable.target_id,
          topic_id: reviewable.topic_id,
          category_id: reviewable.category_id,
          score: reviewable.score,
          created_at: reviewable.created_at.iso8601,
        },
      )
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    it "returns true when reviewable types are blank" do
      trigger = described_class.new(reviewable)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "matches configured reviewable types by STI name" do
      trigger = described_class.new(reviewable)

      expect(
        trigger.matches?(trigger_context("reviewable_types" => ["ReviewableFlaggedPost"])),
      ).to eq(true)
      expect(trigger.matches?(trigger_context("reviewable_types" => ["ReviewableUser"]))).to eq(
        false,
      )
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
