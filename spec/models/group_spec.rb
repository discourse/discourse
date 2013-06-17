require 'spec_helper'

describe Group do

  describe "validation" do
    let(:group) { build(:group) }

    it "is invalid for blank" do
      group.name = ""
      group.valid?.should be_false
    end

    it "is valid for a longer name" do
      group.name = "this_is_a_name"
      group.valid?.should be_true
    end

    it "is invalid for non names" do
      group.name = "this is_a_name"
      group.valid?.should be_false
    end
  end

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

    user2 = Fabricate(:coding_horror)
    user2.change_trust_level!(:regular)

    Group[:trust_level_2].user_ids.sort.should == [user.id, user2.id].sort
  end

  it "Correctly updates all automatic groups upon request" do
    admin = Fabricate(:admin)
    user = Fabricate(:user)
    user.change_trust_level!(:regular)

    Group.exec_sql("update groups set user_count=0 where id = #{Group::AUTO_GROUPS[:trust_level_2]}")

    Group.refresh_automatic_groups!

    groups = Group.includes(:users).to_a
    groups.count.should == Group::AUTO_GROUPS.count

    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:admins]}
    g.users.count.should == 1
    g.user_count.should == 1

    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:staff]}
    g.users.count.should == 1
    g.user_count.should == 1

    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:trust_level_2]}
    g.users.count.should == 1
    g.user_count.should == 1

  end

  it "can set members via usernames helper" do
    g = Fabricate(:group)
    u1 = Fabricate(:user)
    u2 = Fabricate(:user)
    u3 = Fabricate(:user)

    g.add(u1)
    g.save!

    usernames = "#{u2.username},#{u3.username}"

    # no side effects please
    g.usernames = usernames
    g.reload
    g.users.count.should == 1

    g.usernames = usernames
    g.save!

    g.usernames.split(",").sort.should == usernames.split(",").sort
  end

  it "correctly destroys groups" do
    g = Fabricate(:group)
    u1 = Fabricate(:user)
    g.add(u1)
    g.save!

    g.destroy

    User.where(id: u1.id).count.should == 1
    GroupUser.count.should == 0
  end

end
