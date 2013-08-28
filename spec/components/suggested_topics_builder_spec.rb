require 'spec_helper'
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

      builder.results.map(&:id).should == [3,4,2]

      # we have 2 items in category 1
      builder.category_results_left.should == 3
    end

    it "inserts using default approach for non high priority" do
      builder.splice_results([fake_topic(2,2)], :high)
      builder.splice_results([fake_topic(3,1)], :low)

      builder.results.map(&:id).should == [2,3]
    end
  end

  it "has the correct defaults" do
    builder.excluded_topic_ids.include?(topic.id).should be_true
    builder.results_left.should == 5
    builder.size.should == 0
    builder.should_not be_full
  end

  it "returns full correctly" do
    builder.stubs(:results_left).returns(0)
    builder.should be_full
  end

  context "adding results" do

    it "adds nothing with nil results" do
      builder.add_results(nil)
      builder.results_left.should == 5
      builder.size.should == 0
      builder.should_not be_full
    end

    context "adding topics" do
      let!(:other_topic) { Fabricate(:topic) }

      before do
        # Add all topics
        builder.add_results(Topic)
      end

      it "added the result correctly" do
        builder.size.should == 1
        builder.results_left.should == 4
        builder.should_not be_full
        builder.excluded_topic_ids.include?(topic.id).should be_true
        builder.excluded_topic_ids.include?(other_topic.id).should be_true
      end

    end

    context "adding invalid status topics" do
      let!(:archived_topic) { Fabricate(:topic, archived: true)}
      let!(:closed_topic) { Fabricate(:topic, closed: true)}
      let!(:invisible_topic) { Fabricate(:topic, visible: false)}

      it "doesn't add archived, closed or invisible topics" do
        builder.add_results(Topic)
        builder.size.should == 0
        builder.should_not be_full
      end
    end

  end


end
