require 'spec_helper'

describe Group do

  # UGLY but perf is horrible with this callback
  before do
    User.set_callback(:create, :after, :ensure_in_trust_level_group)
  end
  after do
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)
  end

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

  def real_admins
    Group[:admins].user_ids - [-1]
  end

  def real_moderators
    Group[:moderators].user_ids - [-1]
  end

  def real_staff
    Group[:staff].user_ids - [-1]
  end

  it "Can update moderator/staff/admin groups correctly" do

    admin = Fabricate(:admin)
    moderator = Fabricate(:moderator)

    Group.refresh_automatic_groups!(:admins, :staff, :moderators)

    real_admins.should == [admin.id]
    real_moderators.should == [moderator.id]
    real_staff.sort.should == [moderator.id,admin.id].sort

    admin.admin = false
    admin.save

    Group.refresh_automatic_group!(:admins)
    real_admins.should == []

    moderator.revoke_moderation!

    admin.grant_admin!
    real_admins.should == [admin.id]
    real_staff.should == [admin.id]

    admin.revoke_admin!
    real_admins.should == []
    real_staff.should == []

    admin.grant_moderation!
    real_moderators.should == [admin.id]
    real_staff.should == [admin.id]

    admin.revoke_moderation!
    real_admins.should == []
    real_staff.should == []
  end

  it "Correctly updates automatic trust level groups" do
    user = Fabricate(:user)
    Group[:trust_level_0].user_ids.should include user.id

    user.change_trust_level!(:basic)

    Group[:trust_level_1].user_ids.should include user.id

    user.change_trust_level!(:regular)

    Group[:trust_level_1].user_ids.should include user.id
    Group[:trust_level_2].user_ids.should include user.id

    user2 = Fabricate(:coding_horror)
    user2.change_trust_level!(:regular)

    Group[:trust_level_2].user_ids.sort.should == [-1, user.id, user2.id].sort
  end

  it "Correctly updates all automatic groups upon request" do
    Fabricate(:admin)
    user = Fabricate(:user)
    user.change_trust_level!(:regular)

    Group.exec_sql("update groups set user_count=0 where id = #{Group::AUTO_GROUPS[:trust_level_2]}")

    Group.refresh_automatic_groups!

    groups = Group.includes(:users).to_a
    groups.count.should == Group::AUTO_GROUPS.count

    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:admins]}
    g.users.count.should == 2
    g.user_count.should == 2

    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:staff]}
    g.users.count.should == 2
    g.user_count.should == 2


    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:trust_level_1]}
    # admin, system and user
    g.users.count.should == 3
    g.user_count.should == 3

    g = groups.find{|g| g.id == Group::AUTO_GROUPS[:trust_level_2]}
    # system and user
    g.users.count.should == 2
    g.user_count.should == 2

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
    GroupUser.where(group_id: g.id).count.should == 0
  end


  it "has custom fields" do
    group = Fabricate(:group)
    group.custom_fields["a"].should == nil

    group.custom_fields["hugh"] = "jackman"
    group.custom_fields["jack"] = "black"
    group.save

    group = Group.find(group.id)
    group.custom_fields.should == {"hugh" => "jackman", "jack" => "black"}
  end

  it "allows you to lookup a new group by name" do
    group = Fabricate(:group)
    group.id.should == Group[group.name].id
    group.id.should == Group[group.name.to_sym].id
  end

  it "can find desired groups correctly" do
    Group.desired_trust_level_groups(2).sort.should == [10,11,12]
  end


  it "correctly handles trust level changes" do
    user = Fabricate(:user, trust_level: 2)
    Group.user_trust_level_change!(user.id, 2)

    user.groups.map(&:name).sort.should == ["trust_level_0","trust_level_1", "trust_level_2"]

    Group.user_trust_level_change!(user.id, 0)
    user.reload
    user.groups.map(&:name).sort.should == ["trust_level_0"]
  end

end
