require 'spec_helper'
require 'promotion'

describe Promotion do

  context "newuser" do

    let(:user) { Fabricate(:user, trust_level: TrustLevel.levels[:newuser])}
    let(:promotion) { Promotion.new(user) }

    it "doesn't raise an error with a nil user" do
      -> { Promotion.new(nil).review }.should_not raise_error
    end

    context 'that has done nothing' do
      let!(:result) { promotion.review }

      it "returns false" do
        result.should be_false
      end

      it "has not changed the user's trust level" do
        user.trust_level.should == TrustLevel.levels[:newuser]
      end
    end

    context "that has done the requisite things" do

      before do
        stat = user.user_stat
        stat.topics_entered = SiteSetting.basic_requires_topics_entered
        stat.posts_read_count = SiteSetting.basic_requires_read_posts
        stat.time_read = SiteSetting.basic_requires_time_spent_mins * 60
        @result = promotion.review
      end

      it "returns true" do
        @result.should be_true
      end

      it "has upgraded the user to basic" do
        user.trust_level.should == TrustLevel.levels[:basic]
      end
    end

  end

  context "basic" do

    let(:user) { Fabricate(:user, trust_level: TrustLevel.levels[:basic])}
    let(:promotion) { Promotion.new(user) }

    context 'that has done nothing' do
      let!(:result) { promotion.review }

      it "returns false" do
        result.should be_false
      end

      it "has not changed the user's trust level" do
        user.trust_level.should == TrustLevel.levels[:basic]
      end
    end

    context "that has done the requisite things" do

      before do
        stat = user.user_stat
        stat.topics_entered = SiteSetting.regular_requires_topics_entered
        stat.posts_read_count = SiteSetting.regular_requires_read_posts
        stat.time_read = SiteSetting.regular_requires_time_spent_mins * 60
        stat.days_visited = SiteSetting.regular_requires_days_visited * 60
        stat.likes_received = SiteSetting.regular_requires_likes_received
        stat.likes_given = SiteSetting.regular_requires_likes_given
        stat.topic_reply_count = SiteSetting.regular_requires_topic_reply_count

        @result = promotion.review
      end

      it "returns true" do
        @result.should be_true
      end

      it "has upgraded the user to regular" do
        user.trust_level.should == TrustLevel.levels[:regular]
      end
    end

  end

end
