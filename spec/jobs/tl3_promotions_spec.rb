require 'rails_helper'

describe Jobs::Tl3Promotions do

  def create_qualifying_stats(user)
    user.create_user_stat if user.user_stat.nil?
    user.user_stat.update_attributes!(
      days_visited: 1000,
      topic_reply_count: 1000,
      topics_entered: 1000,
      posts_read_count: 1000,
      likes_given: 1000,
      likes_received: 1000
    )
  end

  subject(:run_job) { described_class.new.execute({}) }

  it "promotes tl2 user who qualifies for tl3" do
    tl2_user = Fabricate(:user, trust_level: TrustLevel[2])
    create_qualifying_stats(tl2_user)
    TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(true)
    Promotion.any_instance.expects(:change_trust_level!).with(TrustLevel[3], anything).once
    run_job
  end

  it "promotes a qualifying tl2 user who has a group_granted_trust_level" do
    group = Fabricate(:group, grant_trust_level: 1)
    group_locked_user = Fabricate(:user, trust_level: TrustLevel[2])
    group.add(group_locked_user)

    create_qualifying_stats(group_locked_user)
    TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(true)
    Promotion.any_instance.expects(:change_trust_level!).with(TrustLevel[3], anything).once
    run_job
  end

  it "doesn't promote tl1 and tl0 users who have met tl3 requirements" do
    tl1_user = Fabricate(:user, trust_level: TrustLevel[1])
    tl0_user = Fabricate(:user, trust_level: TrustLevel[0])
    create_qualifying_stats(tl1_user)
    create_qualifying_stats(tl0_user)
    TrustLevel3Requirements.any_instance.expects(:requirements_met?).never
    Promotion.any_instance.expects(:change_trust_level!).never
    run_job
  end

  context "tl3 user who doesn't qualify for tl3 anymore" do
    def create_leader_user
      user = Fabricate(:user, trust_level: TrustLevel[2])
      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(true)
      expect(Promotion.new(user).review_tl2).to eq(true)
      user
    end

    before do
      SiteSetting.tl3_promotion_min_duration = 3
    end

    it "demotes if was promoted more than X days ago" do
      user = nil

      freeze_time 4.days.ago do
        user = create_leader_user
      end

      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(false)
      TrustLevel3Requirements.any_instance.stubs(:requirements_lost?).returns(true)
      run_job
      expect(user.reload.trust_level).to eq(TrustLevel[2])
    end

    it "doesn't demote if user was promoted recently" do
      user = nil
      freeze_time 1.day.ago do
        user = create_leader_user
      end

      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(false)
      TrustLevel3Requirements.any_instance.stubs(:requirements_lost?).returns(true)
      run_job
      expect(user.reload.trust_level).to eq(TrustLevel[3])
    end

    it "doesn't demote if user hasn't lost requirements (low water mark)" do
      user = nil
      freeze_time(4.days.ago) do
        user = create_leader_user
      end

      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(false)
      TrustLevel3Requirements.any_instance.stubs(:requirements_lost?).returns(false)
      run_job
      expect(user.reload.trust_level).to eq(TrustLevel[3])
    end

    it "demotes a user with a group_granted_trust_level of 2" do
      group = Fabricate(:group, grant_trust_level: 2)
      user = nil
      freeze_time(4.days.ago) do
        user = Fabricate(:user, trust_level: TrustLevel[3])
        group.add(user)
      end
      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(false)
      TrustLevel3Requirements.any_instance.stubs(:requirements_lost?).returns(true)
      run_job
      expect(user.reload.trust_level).to eq(TrustLevel[2])

    end

    it "doesn't demote user if their group_granted_trust_level is 3" do
      group = Fabricate(:group, grant_trust_level: 3)
      user = nil
      freeze_time(4.days.ago) do
        user = Fabricate(:user, trust_level: TrustLevel[3])
        group.add(user)
      end
      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(false)
      TrustLevel3Requirements.any_instance.stubs(:requirements_lost?).returns(true)
      run_job
      expect(user.reload.trust_level).to eq(TrustLevel[3])
    end

    it "doesn't demote with very high tl3_promotion_min_duration value" do
      SiteSetting.stubs(:tl3_promotion_min_duration).returns(2000000000)
      user = nil
      freeze_time(500.days.ago) do
        user = create_leader_user
      end
      expect(user).to be_on_tl3_grace_period
      TrustLevel3Requirements.any_instance.stubs(:requirements_met?).returns(false)
      TrustLevel3Requirements.any_instance.stubs(:requirements_lost?).returns(true)
      run_job
      expect(user.reload.trust_level).to eq(TrustLevel[3])
    end
  end
end
