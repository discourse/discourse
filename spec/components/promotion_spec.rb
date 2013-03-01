require 'spec_helper'
require 'promotion'

describe Promotion do

  context "new user" do

    let(:user) { Fabricate(:user, trust_level: TrustLevel.levels[:new])}
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
        user.trust_level.should == TrustLevel.levels[:new]
      end
    end

    context "that has done the requisite things" do

      before do
        user.topics_entered = SiteSetting.basic_requires_topics_entered
        user.posts_read_count = SiteSetting.basic_requires_read_posts
        user.time_read = SiteSetting.basic_requires_time_spent_mins * 60
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


end
