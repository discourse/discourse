require 'spec_helper'
require 'promotion'

describe Promotion do

  describe "review" do
    it "skips regular users" do
      # Reviewing users at higher trust levels is expensive, so trigger those reviews in a background job.
      regular = Fabricate.build(:user, trust_level: TrustLevel[2])
      promotion = described_class.new(regular)
      promotion.expects(:review_tl2).never
      promotion.review
    end
  end

  context "newuser" do

    let(:user) { Fabricate(:user, trust_level: TrustLevel[0])}
    let(:promotion) { Promotion.new(user) }

    it "doesn't raise an error with a nil user" do
      -> { Promotion.new(nil).review }.should_not raise_error
    end

    context 'that has done nothing' do
      let!(:result) { promotion.review }

      it "returns false" do
        result.should == false
      end

      it "has not changed the user's trust level" do
        user.trust_level.should == TrustLevel[0]
      end
    end

    context "that has done the requisite things" do

      before do
        stat = user.user_stat
        stat.topics_entered = SiteSetting.tl1_requires_topics_entered
        stat.posts_read_count = SiteSetting.tl1_requires_read_posts
        stat.time_read = SiteSetting.tl1_requires_time_spent_mins * 60
        @result = promotion.review
      end

      it "returns true" do
        @result.should == true
      end

      it "has upgraded the user to basic" do
        user.trust_level.should == TrustLevel[1]
      end
    end

  end

  context "basic" do

    let(:user) { Fabricate(:user, trust_level: TrustLevel[1])}
    let(:promotion) { Promotion.new(user) }

    context 'that has done nothing' do
      let!(:result) { promotion.review }

      it "returns false" do
        result.should == false
      end

      it "has not changed the user's trust level" do
        user.trust_level.should == TrustLevel[1]
      end
    end

    context "that has done the requisite things" do

      before do
        stat = user.user_stat
        stat.topics_entered = SiteSetting.tl2_requires_topics_entered
        stat.posts_read_count = SiteSetting.tl2_requires_read_posts
        stat.time_read = SiteSetting.tl2_requires_time_spent_mins * 60
        stat.days_visited = SiteSetting.tl2_requires_days_visited * 60
        stat.likes_received = SiteSetting.tl2_requires_likes_received
        stat.likes_given = SiteSetting.tl2_requires_likes_given
        stat.topic_reply_count = SiteSetting.tl2_requires_topic_reply_count

        @result = promotion.review
      end

      it "returns true" do
        @result.should == true
      end

      it "has upgraded the user to regular" do
        user.trust_level.should == TrustLevel[2]
      end
    end

  end

  context "regular" do
    let(:user) { Fabricate(:user, trust_level: TrustLevel[2])}
    let(:promotion) { Promotion.new(user) }

    context "doesn't qualify for promotion" do
      before do
        TrustLevel3Requirements.any_instance.expects(:requirements_met?).at_least_once.returns(false)
      end

      it "review_tl2 returns false" do
        expect {
          promotion.review_tl2.should == false
        }.to_not change { user.reload.trust_level }
      end

      it "doesn't promote" do
        expect {
          promotion.review_tl2
        }.to_not change { user.reload.trust_level }
      end

      it "doesn't log a trust level change" do
        expect {
          promotion.review_tl2
        }.to_not change { UserHistory.count }
      end
    end

    context "qualifies for promotion" do
      before do
        TrustLevel3Requirements.any_instance.expects(:requirements_met?).at_least_once.returns(true)
      end

      it "review_tl2 returns true" do
        promotion.review_tl2.should == true
      end

      it "promotes to tl3" do
        promotion.review_tl2.should == true
        user.reload.trust_level.should == TrustLevel[3]
      end

      it "logs a trust level change" do
        expect {
          promotion.review_tl2
        }.to change { UserHistory.where(action: UserHistory.actions[:auto_trust_level_change]).count }.by(1)
      end
    end
  end

end
