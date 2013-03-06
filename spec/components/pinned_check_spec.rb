require 'pinned_check'

describe PinnedCheck do

  #let(:topic) { Fabricate.build(:topic) }

  let(:pinned_at) { 12.hours.ago }
  let(:unpinned_topic) { Fabricate.build(:topic) }
  let(:pinned_topic) { Fabricate.build(:topic, pinned_at: pinned_at) }

  context "without a topic_user record (either anonymous or never been in the topic)" do

    it "returns false if the topic is not pinned" do
      PinnedCheck.new(unpinned_topic).should_not be_pinned
    end

    it "returns true if the topic is pinned" do
      PinnedCheck.new(unpinned_topic).should_not be_pinned
    end

  end

  context "with a topic_user record" do
    let(:user) { Fabricate.build(:user) }
    let(:unpinned_topic_user) { Fabricate.build(:topic_user, user: user, topic: unpinned_topic) }

    describe "unpinned topic" do
      let(:topic_user) { TopicUser.new(topic: unpinned_topic, user: user) }

      it "returns false" do
        PinnedCheck.new(unpinned_topic, topic_user).should_not be_pinned
      end

    end

    describe "pinned topic" do
      let(:topic_user) { TopicUser.new(topic: pinned_topic, user: user) }

      it "is pinned if the topic_user's cleared_pinned_at is blank" do
        PinnedCheck.new(pinned_topic, topic_user).should be_pinned
      end

      it "is not pinned if the topic_user's cleared_pinned_at is later than when it was pinned_at" do
        topic_user.cleared_pinned_at = (pinned_at + 1.hour)
        PinnedCheck.new(pinned_topic, topic_user).should_not be_pinned
      end

      it "is pinned if the topic_user's cleared_pinned_at is earlier than when it was pinned_at" do
        topic_user.cleared_pinned_at = (pinned_at - 3.hours)
        PinnedCheck.new(pinned_topic, topic_user).should be_pinned
      end
    end


  end

end

