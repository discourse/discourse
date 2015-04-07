require 'spec_helper'

describe AnonymousShadowCreator do

  it "returns no shadow by default" do
    AnonymousShadowCreator.get(Fabricate.build(:user)).should == nil
  end

  it "returns no shadow if trust level is not met" do
    SiteSetting.allow_anonymous_posting = true
    AnonymousShadowCreator.get(Fabricate.build(:user, trust_level: 0)).should == nil
  end

  it "returns a shadow for a legit user" do
    SiteSetting.allow_anonymous_posting = true
    user = Fabricate(:user, trust_level: 3)

    shadow = AnonymousShadowCreator.get(user)
    shadow2 = AnonymousShadowCreator.get(user)

    shadow.id.should == shadow2.id

    shadow.trust_level.should == 1

    shadow.username.should == "anonymous"

  end

end
