require 'rails_helper'
require 'suggested_topics_builder'

describe SuggestedTopicsBuilder do

  let(:topic) { Fabricate(:topic) }
  let(:builder) { SuggestedTopicsBuilder.new(topic) }

  before do
    SiteSetting.stubs(:suggested_topics).returns(5)
  end

  context "splicing category results" do

    def fake_topic(topic_id, category_id)
      build(:topic, id: topic_id, category_id: category_id)
    end

    let(:builder) do
      SuggestedTopicsBuilder.new(fake_topic(1,1))
    end

    it "prioritizes category correctly" do
      builder.splice_results([fake_topic(2,2)], :high)
      builder.splice_results([fake_topic(3,1)], :high)
      builder.splice_results([fake_topic(4,1)], :high)

      expect(builder.results.map(&:id)).to eq([3,4,2])

      # we have 2 items in category 1
      expect(builder.category_results_left).to eq(3)
    end

    it "inserts using default approach for non high priority" do
      builder.splice_results([fake_topic(2,2)], :high)
      builder.splice_results([fake_topic(3,1)], :low)

      expect(builder.results.map(&:id)).to eq([2,3])
    end

    it "inserts multiple results and puts topics in the correct order" do
      builder.splice_results([fake_topic(2,1), fake_topic(3,2), fake_topic(4,1)], :high)
      expect(builder.results.map(&:id)).to eq([2,4,3])
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

  context "adding results" do

    it "adds nothing with nil results" do
      builder.add_results(nil)
      expect(builder.results_left).to eq(5)
      expect(builder.size).to eq(0)
      expect(builder).not_to be_full
    end

    context "adding topics" do
      let!(:other_topic) { Fabricate(:topic) }

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

    context "adding topics that are not open" do
      let!(:archived_topic) { Fabricate(:topic, archived: true)}
      let!(:closed_topic) { Fabricate(:topic, closed: true)}
      let!(:invisible_topic) { Fabricate(:topic, visible: false)}

      it "adds archived and closed, but not invisible topics" do
        builder.add_results(Topic)
        expect(builder.size).to eq(2)
        expect(builder).not_to be_full
      end
    end

    context "category definition topics" do
      let!(:category) { Fabricate(:category) }

      it "doesn't add a category definition topic" do
        expect(category.topic_id).to be_present
        builder.add_results(Topic)
        expect(builder.size).to eq(0)
        expect(builder).not_to be_full
      end
    end

  end


end
