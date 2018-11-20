require 'rails_helper'
require 'pinned_check'

describe PinnedCheck do

  let(:pinned_at) { 12.hours.ago }
  let(:unpinned_topic) { Fabricate.build(:topic) }
  let(:pinned_topic) { Fabricate.build(:topic, pinned_at: pinned_at) }

  context "without a topic_user record (either anonymous or never been in the topic)" do

    it "returns false if the topic is not pinned" do
      expect(PinnedCheck.pinned?(unpinned_topic)).to eq(false)
    end

    it "returns true if the topic is pinned" do
      expect(PinnedCheck.pinned?(unpinned_topic)).to eq(false)
    end

  end

  context "with a topic_user record" do
    let(:user) { Fabricate.build(:user) }
    let(:unpinned_topic_user) { Fabricate.build(:topic_user, user: user, topic: unpinned_topic) }

    describe "unpinned topic" do
      let(:topic_user) { TopicUser.new(topic: unpinned_topic, user: user) }

      it "returns false" do
        expect(PinnedCheck.pinned?(unpinned_topic, topic_user)).to eq(false)
      end

    end

    describe "pinned topic" do
      let(:topic_user) { TopicUser.new(topic: pinned_topic, user: user) }

      it "is pinned if the topic_user's cleared_pinned_at is blank" do
        expect(PinnedCheck.pinned?(pinned_topic, topic_user)).to eq(true)
      end

      it "is not pinned if the topic_user's cleared_pinned_at is later than when it was pinned_at" do
        topic_user.cleared_pinned_at = (pinned_at + 1.hour)
        expect(PinnedCheck.pinned?(pinned_topic, topic_user)).to eq(false)
      end

      it "is pinned if the topic_user's cleared_pinned_at is earlier than when it was pinned_at" do
        topic_user.cleared_pinned_at = (pinned_at - 3.hours)
        expect(PinnedCheck.pinned?(pinned_topic, topic_user)).to eq(true)
      end
    end

  end

end
