require 'spec_helper'
require 'boost_trust_level'
require 'admin_logger'

describe BoostTrustLevel do

  let(:user) { Fabricate(:user) }
  let(:logger) { AdminLogger.new(Fabricate(:admin)) }


  it "should upgrade the trust level of a user" do
    boostr = BoostTrustLevel.new(user: user, level: TrustLevel.levels[:basic], logger: logger)
    boostr.save!.should be_true
    user.trust_level.should == TrustLevel.levels[:basic]
  end

  it "should log the action" do
    AdminLogger.any_instance.expects(:log_trust_level_change).with(user, TrustLevel.levels[:basic]).once
    boostr = BoostTrustLevel.new(user: user, level: TrustLevel.levels[:basic], logger: logger)
    boostr.save!
  end

  describe "demotions" do
    before { user.update_attributes(trust_level: TrustLevel.levels[:newuser]) }

    context "for a user that has not done the requisite things to attain their trust level" do

      before do
        # scenario: admin mistakenly promotes user's trust level
        user.update_attributes(trust_level: TrustLevel.levels[:basic])
      end

      it "should demote the user and log the action" do
        AdminLogger.any_instance.expects(:log_trust_level_change).with(user, TrustLevel.levels[:newuser]).once
        boostr = BoostTrustLevel.new(user: user, level: TrustLevel.levels[:newuser], logger: logger)
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

      it "should not demote the user and not log the action" do
        AdminLogger.any_instance.expects(:log_trust_level_change).with(user, TrustLevel.levels[:newuser]).never
        boostr = BoostTrustLevel.new(user: user, level: TrustLevel.levels[:newuser], logger: logger)
        expect { boostr.save! }.to raise_error(Discourse::InvalidAccess, "You attempted to demote #{user.name} to 'newuser'. However their trust level is already 'basic'. #{user.name} will remain at 'basic'")
        user.trust_level.should == TrustLevel.levels[:basic]
      end

    end
  end
end
