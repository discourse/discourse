require 'spec_helper'

describe AnonymousShadowCreator do

  it "returns no shadow by default" do
    AnonymousShadowCreator.get(Fabricate.build(:user)).should == nil
  end

  it "returns no shadow if trust level is not met" do
    SiteSetting.allow_anonymous_posting = true
    AnonymousShadowCreator.get(Fabricate.build(:user, trust_level: 0)).should == nil
  end

  it "returns a new shadow once time expires" do
    SiteSetting.allow_anonymous_posting = true
    SiteSetting.anonymous_account_duration_minutes = 1

    user = Fabricate(:user, trust_level: 3)
    shadow = AnonymousShadowCreator.get(user)

    freeze_time 2.minutes.from_now
    shadow2 = AnonymousShadowCreator.get(user)

    shadow.id.should == shadow2.id
    create_post(user: shadow)

    freeze_time 4.minutes.from_now
    shadow3 = AnonymousShadowCreator.get(user)

    shadow2.id.should_not == shadow3.id

  end

  it "returns a shadow for a legit user" do
    SiteSetting.allow_anonymous_posting = true
    user = Fabricate(:user, trust_level: 3)

    shadow = AnonymousShadowCreator.get(user)
    shadow2 = AnonymousShadowCreator.get(user)

    shadow.id.should == shadow2.id

    shadow.trust_level.should == 1
    shadow.username.should == "anonymous"

    shadow.created_at.should_not == user.created_at


    p = create_post
    Guardian.new(shadow).post_can_act?(p, :like).should == false
    Guardian.new(user).post_can_act?(p, :like).should == true

    user.anonymous?.should == false
    shadow.anonymous?.should == true
  end

end
