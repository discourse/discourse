# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ReviewableStatusChanged::V1 do
  fab!(:reviewable, :reviewable_flagged_post)

  let(:fixed_triggers) do
    Reviewable.statuses.keys.to_h do |status|
      [status, DiscourseWorkflows::Registry.find_node_type("trigger:reviewable_#{status}")]
    end
  end

  describe ".property_schema" do
    it "exposes fixed outcomes while keeping the generic status selector for existing nodes" do
      expect(described_class.palette_visible?).to eq(false)
      expect(described_class.property_schema).to have_key(:statuses)

      fixed_triggers.each_value do |node_class|
        expect(node_class.palette_visible?).to eq(true)
        expect(node_class.property_schema.keys).to eq([:reviewable_types])
      end
    end
  end

  describe "#valid?" do
    it "accepts every review outcome for existing reviewables" do
      Reviewable.statuses.each_key do |status|
        expect(described_class.new(status, reviewable)).to be_valid
      end

      expect(described_class.new(:unknown, reviewable)).not_to be_valid
      expect(described_class.new(:rejected, nil)).not_to be_valid
    end

    it "restricts each fixed trigger to its outcome" do
      fixed_triggers.each do |outcome, node_class|
        Reviewable.statuses.each_key do |status|
          expect(node_class.new(status, reviewable).valid?).to eq(status == outcome)
        end

        expect(node_class.new(outcome, nil)).not_to be_valid
      end
    end
  end

  describe "#matches?" do
    it "filters by outcome and reviewable type" do
      trigger = described_class.new(:rejected, reviewable)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(
        trigger.matches?(
          trigger_context(
            "statuses" => ["rejected"],
            "reviewable_types" => ["ReviewableFlaggedPost"],
          ),
        ),
      ).to eq(true)
      expect(trigger.matches?(trigger_context("statuses" => ["approved"]))).to eq(false)
      expect(trigger.matches?(trigger_context("reviewable_types" => ["ReviewableUser"]))).to eq(
        false,
      )
    end

    it "keeps fixed outcomes when statuses are supplied and still filters by reviewable type" do
      fixed_triggers.each do |outcome, node_class|
        trigger = node_class.new(outcome, reviewable)
        statuses = Reviewable.statuses.keys - [outcome]

        expect(trigger.matches?(trigger_context({}))).to eq(true)
        expect(
          trigger.matches?(
            trigger_context("statuses" => statuses, "reviewable_types" => [reviewable.type]),
          ),
        ).to eq(true)
        expect(trigger.matches?(trigger_context("reviewable_types" => ["ReviewableUser"]))).to eq(
          false,
        )
      end
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
