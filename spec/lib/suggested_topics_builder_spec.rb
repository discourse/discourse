# frozen_string_literal: true

require "suggested_topics_builder"

RSpec.describe SuggestedTopicsBuilder do
  fab!(:topic)
  let(:builder) { SuggestedTopicsBuilder.new(topic) }

  before { SiteSetting.suggested_topics = 5 }

  describe "splicing category results" do
    def fake_topic(topic_id, category_id)
      build(:topic, id: topic_id, category_id: category_id)
    end

    let(:builder) { SuggestedTopicsBuilder.new(fake_topic(1, 1)) }

    it "prioritizes category correctly" do
      builder.splice_results([fake_topic(2, 2)], :high)
      builder.splice_results([fake_topic(3, 1)], :high)
      builder.splice_results([fake_topic(4, 1)], :high)

      expect(builder.results.map(&:id)).to eq([3, 4, 2])

      # we have 2 items in category 1
      expect(builder.category_results_left).to eq(3)
    end

    it "inserts using default approach for non high priority" do
      builder.splice_results([fake_topic(2, 2)], :high)
      builder.splice_results([fake_topic(3, 1)], :low)

      expect(builder.results.map(&:id)).to eq([2, 3])
    end

    it "inserts multiple results and puts topics in the correct order" do
      builder.splice_results([fake_topic(2, 1), fake_topic(3, 2), fake_topic(4, 1)], :high)
      expect(builder.results.map(&:id)).to eq([2, 4, 3])
    end
  end

  it "has the correct defaults" do
    expect(builder.excluded_topic_ids.include?(topic.id)).to eq(true)
    expect(builder.results_left).to eq(5)
    expect(builder.size).to eq(0)
    expect(builder).not_to be_full
  end

  it "returns full correctly" do
    builder.stubs(:results_left).returns(0)
    expect(builder).to be_full
  end

  describe "adding results" do
    it "adds nothing with nil results" do
      builder.add_results(nil)
      expect(builder.results_left).to eq(5)
      expect(builder.size).to eq(0)
      expect(builder).not_to be_full
    end

    context "when adding topics" do
      fab!(:other_topic) { Fabricate(:topic) }

      before do
        # Add all topics
        builder.add_results(Topic)
      end

      it "added the result correctly" do
        expect(builder.size).to eq(1)
        expect(builder.results_left).to eq(4)
        expect(builder).not_to be_full
        expect(builder.excluded_topic_ids.include?(topic.id)).to eq(true)
        expect(builder.excluded_topic_ids.include?(other_topic.id)).to eq(true)
      end
    end

    context "when adding topics that are not open" do
      fab!(:archived_topic) { Fabricate(:topic, archived: true) }
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }
      fab!(:invisible_topic) { Fabricate(:topic, visible: false) }

      it "adds archived and closed, but not invisible topics" do
        builder.add_results(Topic)
        expect(builder.size).to eq(2)
        expect(builder).not_to be_full
      end
    end

    context "when category definition topics" do
      fab!(:category) { Fabricate(:category_with_definition) }

      it "doesn't add a category definition topic" do
        expect(category.topic_id).to be_present
        builder.add_results(Topic)
        expect(builder.size).to eq(0)
        expect(builder).not_to be_full
      end
    end

    context "with suggested_topics_add_results modifier registered" do
      fab!(:included_topic) { Fabricate(:topic) }
      fab!(:excluded_topic) { Fabricate(:topic) }

      let(:modifier_block) do
        Proc.new { |results| results.filter { |topic| topic.id != excluded_topic.id } }
      end

      it "Allows modifications to added results" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:suggested_topics_add_results, &modifier_block)

        builder.add_results(Topic.where(id: [included_topic.id, excluded_topic.id]))

        expect(builder.results).to include(included_topic)
        expect(builder.results).not_to include(excluded_topic)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :suggested_topics_add_results,
          &modifier_block
        )
      end
    end
  end
end
