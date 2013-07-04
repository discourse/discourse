require 'spec_helper'
require 'boost_trust_level'

describe BoostTrustLevel do

  let(:user) { Fabricate(:user) }

  it "should upgrade the trust level of a user" do
    boostr = BoostTrustLevel.new(user, TrustLevel.levels[:basic])
    boostr.save!.should be_true
    user.trust_level.should == TrustLevel.levels[:basic]
  end

  describe "demotions" do
    before { user.update_attributes(trust_level: TrustLevel.levels[:newuser]) }

    context "for a user that has not done the requisite things to attain their trust level" do

      before do
        # scenario: admin mistakenly promotes user's trust level
        user.update_attributes(trust_level: TrustLevel.levels[:basic])
      end

      it "should demote the user" do
        boostr = BoostTrustLevel.new(user, TrustLevel.levels[:newuser])
        boostr.save!.should be_true
        user.trust_level.should == TrustLevel.levels[:newuser]
      end
    end

    context "for a user that has done the requisite things to attain their trust level" do

      before do
        user.topics_entered = SiteSetting.basic_requires_topics_entered + 1
        user.posts_read_count = SiteSetting.basic_requires_read_posts + 1
        user.time_read = SiteSetting.basic_requires_time_spent_mins * 60
        user.save!
        user.update_attributes(trust_level: TrustLevel.levels[:basic])
      end

      it "should not demote the user" do
        boostr = BoostTrustLevel.new(user, TrustLevel.levels[:newuser])
        expect { boostr.save! }.to raise_error(Discourse::InvalidAccess, "You attempted to demote #{user.name} to 'newuser'. However their trust level is already 'basic'. #{user.name} will remain at 'basic'")
        user.trust_level.should == TrustLevel.levels[:basic]
      end
    end
  end
end
