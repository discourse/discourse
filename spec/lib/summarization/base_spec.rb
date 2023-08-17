# frozen_string_literal: true

describe Summarization::Base do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  fab!(:topic) { Fabricate(:topic) }

  let(:plugin) { Plugin::Instance.new }

  before do
    group.add(user)

    strategy = DummyCustomSummarization.new({ summary: "dummy", chunks: [] })
    plugin.register_summarization_strategy(strategy)
    SiteSetting.summarization_strategy = strategy.model
  end

  after { DiscoursePluginRegistry.reset_register!(:summarization_strategies) }

  describe "#can_see_summary?" do
    context "when the user cannot generate a summary" do
      before { SiteSetting.custom_summarization_allowed_groups = "" }

      it "returns false" do
        SiteSetting.custom_summarization_allowed_groups = ""

        expect(described_class.can_see_summary?(topic, user)).to eq(false)
      end

      it "returns true if there is a cached summary" do
        SummarySection.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
          meta_section_id: nil,
        )

        expect(described_class.can_see_summary?(topic, user)).to eq(true)
      end
    end

    context "when the user can generate a summary" do
      before { SiteSetting.custom_summarization_allowed_groups = group.id }

      it "returns true if the user group is present in the custom_summarization_allowed_groups_map setting" do
        expect(described_class.can_see_summary?(topic, user)).to eq(true)
      end
    end

    context "when there is no user" do
      it "returns false for anons" do
        expect(described_class.can_see_summary?(topic, nil)).to eq(false)
      end

      it "returns true for anons when there is a cached summary" do
        SummarySection.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
          meta_section_id: nil,
        )

        expect(described_class.can_see_summary?(topic, nil)).to eq(true)
      end
    end
  end
end
