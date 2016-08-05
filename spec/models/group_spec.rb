require 'rails_helper'

describe Group do

  describe '#builtin' do
    context "verify enum sequence" do
      before do
        @builtin = Group.builtin
      end

      it "'moderators' should be at 1st position" do
        expect(@builtin[:moderators]).to eq(1)
      end

      it "'trust_level_2' should be at 4th position" do
        expect(@builtin[:trust_level_2]).to eq(4)
      end
    end
  end

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
      expect(group.valid?).to eq false
    end

    it "is valid for a longer name" do
      group.name = "this_is_a_name"
      expect(group.valid?).to eq true
    end

    it "is invalid for non names" do
      group.name = "this is_a_name"
      expect(group.valid?).to eq false
    end

    it "is invalid for case-insensitive existing names" do
      build(:group, name: 'this_is_a_name').save
      group.name = 'This_Is_A_Name'
      expect(group.valid?).to eq false
    end

    it "is invalid for poorly formatted domains" do
      group.automatic_membership_email_domains = "wikipedia.org|*@example.com"
      expect(group.valid?).to eq false
    end

    it "is valid for proper domains" do
      group.automatic_membership_email_domains = "discourse.org|wikipedia.org"
      expect(group.valid?).to eq true
    end

    it "is valid for newer TLDs" do
      group.automatic_membership_email_domains = "discourse.institute"
      expect(group.valid?).to eq true
    end

    it "is invalid for bad incoming email" do
      group.incoming_email = "foo.bar.org"
      expect(group.valid?).to eq(false)
    end

    it "is valid for proper incoming email" do
      group.incoming_email = "foo@bar.org"
      expect(group.valid?).to eq(true)
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

  it "Correctly handles primary groups" do
    group = Fabricate(:group, primary_group: true)
    user = Fabricate(:user)

    group.add(user)

    user.reload
    expect(user.primary_group_id).to eq group.id

    group.remove(user)

    user.reload
    expect(user.primary_group_id).to eq nil

    group.add(user)
    group.primary_group = false
    group.save

    user.reload
    expect(user.primary_group_id).to eq nil

  end

  it "Correctly handles title" do

    group = Fabricate(:group, title: 'Super Awesome')
    user = Fabricate(:user)

    expect(user.title).to eq nil

    group.add(user)
    user.reload

    expect(user.title).to eq 'Super Awesome'

    group.title = 'BOOM'
    group.save

    user.reload
    expect(user.title).to eq 'BOOM'

    group.title = nil
    group.save

    user.reload
    expect(user.title).to eq nil

    group.title = "BOB"
    group.save

    user.reload
    expect(user.title).to eq "BOB"

    group.remove(user)

    user.reload
    expect(user.title).to eq nil

    group.add(user)
    group.destroy

    user.reload
    expect(user.title).to eq nil

  end

  it "Correctly handles removal of primary group" do
    group = Fabricate(:group)
    user = Fabricate(:user)
    group.add(user)
    group.save

    user.primary_group = group
    user.save

    group.reload

    group.remove(user)
    group.save

    user.reload
    expect(user.primary_group).to eq nil
  end

  it "Can update moderator/staff/admin groups correctly" do

    admin = Fabricate(:admin)
    moderator = Fabricate(:moderator)

    Group.refresh_automatic_groups!(:admins, :staff, :moderators)

    expect(real_admins).to eq [admin.id]
    expect(real_moderators).to eq [moderator.id]
    expect(real_staff.sort).to eq [moderator.id,admin.id].sort

    admin.admin = false
    admin.save

    Group.refresh_automatic_group!(:admins)
    expect(real_admins).to be_empty

    moderator.revoke_moderation!

    admin.grant_admin!
    expect(real_admins).to eq [admin.id]
    expect(real_staff).to eq [admin.id]

    admin.revoke_admin!
    expect(real_admins).to be_empty
    expect(real_staff).to be_empty

    admin.grant_moderation!
    expect(real_moderators).to eq [admin.id]
    expect(real_staff).to eq [admin.id]

    admin.revoke_moderation!
    expect(real_admins).to be_empty
    expect(real_staff).to eq []
  end

  it "Correctly updates automatic trust level groups" do
    user = Fabricate(:user)
    expect(Group[:trust_level_0].user_ids).to include user.id

    user.change_trust_level!(TrustLevel[1])

    expect(Group[:trust_level_1].user_ids).to include user.id

    user.change_trust_level!(TrustLevel[2])

    expect(Group[:trust_level_1].user_ids).to include user.id
    expect(Group[:trust_level_2].user_ids).to include user.id

    user2 = Fabricate(:coding_horror)
    user2.change_trust_level!(TrustLevel[3])

    expect(Group[:trust_level_2].user_ids.sort).to eq [-1, user.id, user2.id].sort
  end

  it "Correctly updates all automatic groups upon request" do
    Fabricate(:admin)
    user = Fabricate(:user)
    user.change_trust_level!(TrustLevel[2])

    Group.exec_sql("update groups set user_count=0 where id = #{Group::AUTO_GROUPS[:trust_level_2]}")

    Group.refresh_automatic_groups!

    groups = Group.includes(:users).to_a
    expect(groups.count).to eq Group::AUTO_GROUPS.count

    g = groups.find{|grp| grp.id == Group::AUTO_GROUPS[:admins]}
    expect(g.users.count).to eq 2
    expect(g.user_count).to eq 2

    g = groups.find{|grp| grp.id == Group::AUTO_GROUPS[:staff]}
    expect(g.users.count).to eq 2
    expect(g.user_count).to eq 2

    g = groups.find{|grp| grp.id == Group::AUTO_GROUPS[:trust_level_1]}
    # admin, system and user
    expect(g.users.count).to eq 3
    expect(g.user_count).to eq 3

    g = groups.find{|grp| grp.id == Group::AUTO_GROUPS[:trust_level_2]}
    # system and user
    expect(g.users.count).to eq 2
    expect(g.user_count).to eq 2

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
    expect(g.users.count).to eq 1

    g.usernames = usernames
    g.save!

    expect(g.usernames.split(",").sort).to eq usernames.split(",").sort
  end

  it "correctly destroys groups" do

    g = Fabricate(:group)
    u1 = Fabricate(:user)
    g.add(u1)
    g.save!

    g.destroy

    expect(User.where(id: u1.id).count).to eq 1
    expect(GroupUser.where(group_id: g.id).count).to eq 0
  end


  it "has custom fields" do
    group = Fabricate(:group)
    expect(group.custom_fields["a"]).to be_nil

    group.custom_fields["hugh"] = "jackman"
    group.custom_fields["jack"] = "black"
    group.save

    group = Group.find(group.id)
    expect(group.custom_fields).to eq({"hugh" => "jackman", "jack" => "black"})
  end

  it "allows you to lookup a new group by name" do
    group = Fabricate(:group)
    expect(group.id).to eq Group[group.name].id
    expect(group.id).to eq Group[group.name.to_sym].id
  end

  it "can find desired groups correctly" do
    expect(Group.desired_trust_level_groups(2).sort).to eq [10,11,12]
  end


  it "correctly handles trust level changes" do
    user = Fabricate(:user, trust_level: 2)
    Group.user_trust_level_change!(user.id, 2)

    expect(user.groups.map(&:name).sort).to eq ["trust_level_0","trust_level_1", "trust_level_2"]

    Group.user_trust_level_change!(user.id, 0)
    user.reload
    expect(user.groups.map(&:name).sort).to eq ["trust_level_0"]
  end

  context "group management" do
    let(:group) {Fabricate(:group)}

    it "by default has no managers" do
      expect(group.group_users.where('group_users.owner')).to be_empty
    end

    it "multiple managers can be appointed" do
      2.times do |i|
        u = Fabricate(:user)
        group.add_owner(u)
      end
      expect(group.group_users.where('group_users.owner').count).to eq(2)
    end

    it "manager has authority to edit membership" do
      u = Fabricate(:user)
      expect(Guardian.new(u).can_edit?(group)).to be_falsy
      group.add_owner(u)
      expect(Guardian.new(u).can_edit?(group)).to be_truthy
    end
  end

  it "correctly grants a trust level to members" do
    group = Fabricate(:group, grant_trust_level: 2)
    u0 = Fabricate(:user, trust_level: 0)
    u3 = Fabricate(:user, trust_level: 3)

    group.add(u0)
    expect(u0.reload.trust_level).to eq(2)

    group.add(u3)
    expect(u3.reload.trust_level).to eq(3)
  end

end
