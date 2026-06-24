# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ReviewableApproved::V1 do
  fab!(:reviewable, :reviewable_flagged_post)

  describe ".property_schema" do
    it "includes reviewable type options for the multi-select control" do
      expect(described_class.property_schema.dig(:reviewable_types, :options)).to include(
        { value: "ReviewableFlaggedPost", label: "Reviewable flagged post" },
      )
    end
  end

  describe ".load_options_context" do
    it "returns core and plugin reviewable types" do
      plugin_instance = Plugin::Instance.new
      plugin_reviewable_type =
        Class.new(Reviewable) do
          def self.name
            "CustomReviewableType"
          end
        end

      plugin_instance.register_reviewable_type(plugin_reviewable_type)

      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "reviewable_types",
          filter: "reviewable",
        )

      expect(described_class.load_options_context(context)).to include(
        { id: "ReviewableFlaggedPost", name: "Reviewable flagged post" },
        { id: "CustomReviewableType", name: "Custom reviewable type" },
      )
    ensure
      DiscoursePluginRegistry._raw_reviewable_types.reject! do |entry|
        entry[:value] == plugin_reviewable_type
      end
    end
  end

  describe "#valid?" do
    it "returns true when a reviewable is approved" do
      trigger = described_class.new(:approved, reviewable)

      expect(trigger).to be_valid
    end

    it "returns false for other reviewable transitions" do
      trigger = described_class.new(:rejected, reviewable)

      expect(trigger).not_to be_valid
    end

    it "returns false when the reviewable is missing" do
      trigger = described_class.new(:approved, nil)

      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns reviewable data only" do
      reviewable.update!(status: :approved)
      trigger = described_class.new(:approved, reviewable)

      expect(trigger.output).to eq(
        reviewable: {
          id: reviewable.id,
          type: "ReviewableFlaggedPost",
          status: "approved",
          target_type: "Post",
          target_id: reviewable.target_id,
          topic_id: reviewable.topic_id,
          category_id: reviewable.category_id,
          score: reviewable.score,
          created_at: reviewable.created_at.iso8601,
        },
      )
    end
  end

  describe "#matches?" do
    it "returns true when reviewable types are blank" do
      trigger = described_class.new(:approved, reviewable)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "matches configured reviewable types by STI name" do
      trigger = described_class.new(:approved, reviewable)

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
