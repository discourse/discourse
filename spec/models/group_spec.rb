require 'spec_helper'

describe Group do

  it "Can update moderator/staff/admin groups correctly" do
    admin = Fabricate(:admin)
    moderator = Fabricate(:moderator)

    Group.refresh_automatic_groups!(:admins, :staff, :moderators)

    Group[:admins].user_ids.should == [admin.id]
    Group[:moderators].user_ids.should == [moderator.id]
    Group[:staff].user_ids.sort.should == [moderator.id,admin.id].sort

    admin.admin = false
    admin.save

    Group.refresh_automatic_group!(:admins)
    Group[:admins].user_ids.should == []

    moderator.revoke_moderation!

    admin.grant_admin!
    Group[:admins].user_ids.should == [admin.id]
    Group[:staff].user_ids.should == [admin.id]

    admin.revoke_admin!
    Group[:admins].user_ids.should == []
    Group[:staff].user_ids.should == []

    admin.grant_moderation!
    Group[:moderators].user_ids.should == [admin.id]
    Group[:staff].user_ids.should == [admin.id]

    admin.revoke_moderation!
    Group[:admins].user_ids.should == []
    Group[:staff].user_ids.should == []
  end

  it "Correctly updates automatic trust level groups" do
    user = Fabricate(:user)
    user.change_trust_level!(:basic)

    Group[:trust_level_1].user_ids.should == [user.id]

    user.change_trust_level!(:regular)

    Group[:trust_level_1].user_ids.should == []
    Group[:trust_level_2].user_ids.should == [user.id]
  end

end
