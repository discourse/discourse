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

  it "demotes tl3 user who doesn't qualify for tl3 anymore" do
    tl3_user = Fabricate(:user, trust_level: TrustLevel.levels[:leader])
    LeaderRequirements.any_instance.stubs(:requirements_met?).returns(false)
    Promotion.any_instance.expects(:change_trust_level!).with(:regular, anything).once
    run_job
  end
end
