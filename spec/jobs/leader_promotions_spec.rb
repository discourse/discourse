require 'spec_helper'

describe Jobs::LeaderPromotions do

  subject(:run_job) { described_class.new.execute({}) }

  it "promotes tl2 user who qualifies for tl3" do
    tl2_user = Fabricate(:user, trust_level: TrustLevel.levels[:regular])
    LeaderRequirements.any_instance.stubs(:requirements_met?).returns(true)
    Promotion.any_instance.expects(:change_trust_level!).with(:leader, anything).once
    run_job
  end

  it "doesn't promote tl1 and tl0 users who have met tl3 requirements" do
    tl1_user = Fabricate(:user, trust_level: TrustLevel.levels[:basic])
    tl0_user = Fabricate(:user, trust_level: TrustLevel.levels[:newuser])
    LeaderRequirements.any_instance.expects(:requirements_met?).never
    Promotion.any_instance.expects(:change_trust_level!).never
    run_job
  end

  context "tl3 user who doesn't qualify for tl3 anymore" do
    def create_leader_user
      user = Fabricate(:user, trust_level: TrustLevel.levels[:regular])
      LeaderRequirements.any_instance.stubs(:requirements_met?).returns(true)
      Promotion.new(user).review_regular.should == true
      user
    end

    before do
      SiteSetting.stubs(:leader_promotion_min_duration).returns(3)
    end

    it "demotes if was promoted more than X days ago" do
      user = nil
      Timecop.freeze(4.days.ago) do
        user = create_leader_user
      end

      LeaderRequirements.any_instance.stubs(:requirements_met?).returns(false)
      run_job
      user.reload.trust_level.should == TrustLevel.levels[:regular]
    end

    it "doesn't demote if user was promoted recently" do
      user = nil
      Timecop.freeze(1.day.ago) do
        user = create_leader_user
      end

      LeaderRequirements.any_instance.stubs(:requirements_met?).returns(false)
      run_job
      user.reload.trust_level.should == TrustLevel.levels[:leader]
    end
  end
end
