# frozen_string_literal: true

RSpec.describe TopicViewSerializer do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, highest_post_number: 1) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }

  let(:guardian) { Guardian.new(user) }
  let(:topic_view) { TopicView.new(topic, user) }
  let(:serializer) { described_class.new(topic_view, scope: guardian, root: false) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#ai_summary" do
    let!(:summary) do
      AiSummary.store!(
        DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
        build(:llm_model),
        "Test summary content",
        [{ id: post_1.id }],
        human: false,
      )
    end

    context "when serialize_ai_summary modifier is not enabled" do
      it "does not include ai_summary even when summary exists" do
        json = serializer.as_json

        expect(json[:ai_summary]).to be_nil
      end
    end

    context "when serialize_ai_summary modifier is enabled" do
      let(:plugin_instance) { Plugin::Instance.new }
      let(:modifier_block) { Proc.new { true } }

      before do
        DiscoursePluginRegistry.register_modifier(
          plugin_instance,
          :serialize_ai_summary,
          &modifier_block
        )
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :serialize_ai_summary,
          &modifier_block
        )
      end

      it "includes ai_summary with all expected fields" do
        json = serializer.as_json

        expect(json[:ai_summary]).to be_present
        expect(json[:ai_summary][:id]).to eq(summary.id)
        expect(json[:ai_summary][:summarized_text]).to eq("Test summary content")
        expect(json[:ai_summary][:algorithm]).to eq(summary.algorithm)
        expect(json[:ai_summary][:outdated]).to eq(false)
        expect(json[:ai_summary][:created_at]).to be_present
        expect(json[:ai_summary][:updated_at]).to be_present
      end

      it "does not include ai_summary when summarization is disabled" do
        SiteSetting.ai_summarization_enabled = false

        json = serializer.as_json

        expect(json[:ai_summary]).to be_nil
      end

      it "does not include ai_summary when no complete summary exists" do
        summary.destroy!

        json = serializer.as_json

        expect(json[:ai_summary]).to be_nil
      end
    end
  end
end
