# frozen_string_literal: true

require 'rails_helper'

describe Group do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }

  context 'validations' do
    describe '#grant_trust_level' do
      describe 'when trust level is not valid' do
        it 'should not be valid' do
          group.grant_trust_level = 123456

          expect(group.valid?).to eq(false)

          expect(group.errors.full_messages.join(",")).to eq(I18n.t(
            'groups.errors.grant_trust_level_not_valid',
            trust_level: 123456
          ))
        end
      end
    end

    describe '#name' do
      context 'when a user with a similar name exists' do
        it 'should not be valid' do
          new_group = Fabricate.build(:group, name: admin.username.upcase)

          expect(new_group).to_not be_valid

          expect(new_group.errors.full_messages.first)
            .to include(I18n.t("activerecord.errors.messages.taken"))
        end
      end

      context 'when a group with a similar name exists' do
        it 'should not be valid' do
          new_group = Fabricate.build(:group, name: group.name.upcase)

          expect(new_group).to_not be_valid

          expect(new_group.errors.full_messages.first)
            .to include(I18n.t("activerecord.errors.messages.taken"))
        end
      end
    end
  end

  describe "#posts_for" do
    it "returns the post in the group" do
      p = Fabricate(:post)
      group.add(p.user)

      posts = group.posts_for(Guardian.new)
      expect(posts).to include(p)
    end

    it "doesn't include unlisted posts" do
      p = Fabricate(:post)
      p.topic.update_column(:visible, false)
      group.add(p.user)

      posts = group.posts_for(Guardian.new)
      expect(posts).not_to include(p)
    end
  end

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

    it 'strips trailing and leading spaces' do
      group.name = '  dragon  '

      expect(group.save).to eq(true)
      expect(group.reload.name).to eq('dragon')
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

    context 'when a group has no owners' do
      describe 'group has not been persisted' do
        it 'should not allow membership requests' do
          group = Fabricate.build(:group, allow_membership_requests: true)

          expect(group.valid?).to eq(false)

          expect(group.errors.full_messages).to include(I18n.t(
            "groups.errors.cant_allow_membership_requests"
          ))

          group.group_users.build(user_id: user.id, owner: true)

          expect(group.valid?).to eq(true)
        end
      end

      it 'should not allow membership requests' do
        group.allow_membership_requests = true

        expect(group.valid?).to eq(false)

        expect(group.errors.full_messages).to include(I18n.t(
          "groups.errors.cant_allow_membership_requests"
        ))

        group.allow_membership_requests = false
        group.save!

        group.add_owner(user)
        group.allow_membership_requests = true

        expect(group.valid?).to eq(true)
      end
    end
  end

  def real_admins
    Group[:admins].user_ids.reject { |id| id < 0 }
  end

  def real_moderators
    Group[:moderators].user_ids.reject { |id| id < 0 }
  end

  def real_staff
    Group[:staff].user_ids.reject { |id| id < 0 }
  end

  describe '#primary_group=' do
    it "updates all members' #primary_group" do
      group.add(user)

      expect { group.update(primary_group: true) }.to change { user.reload.primary_group }.from(nil).to(group)
      expect { group.update(primary_group: false) }.to change { user.reload.primary_group }.from(group).to(nil)
    end
  end

  describe '#title=' do
    it "updates the member's title only if it was blank or exact match" do
      group.add(user)

      expect { group.update(title: 'Awesome') }.to change { user.reload.title }.from(nil).to('Awesome')
      expect { group.update(title: 'Super') }.to change { user.reload.title }.from('Awesome').to('Super')

      user.update(title: 'Differently Awesome')
      expect { group.update(title: 'Awesome') }.to_not change { user.reload.title }
    end

    it "doesn't update non-member's title" do
      user.update(title: group.title)
      expect { group.update(title: 'Super') }.to_not change { user.reload.title }
    end
  end

  describe '.refresh_automatic_group!' do

    it "does not include staged users in any automatic groups" do
      staged = Fabricate(:staged, trust_level: 1)

      Group.refresh_automatic_group!(:trust_level_0)
      Group.refresh_automatic_group!(:trust_level_1)

      expect(GroupUser.where(user_id: staged.id).count).to eq(0)

      staged.unstage
      staged.save!

      expect(GroupUser.where(user_id: staged.id).count).to eq(2)
    end

    it "makes sure the everyone group is not visible except to staff" do
      g = Group.refresh_automatic_group!(:everyone)
      expect(g.visibility_level).to eq(Group.visibility_levels[:staff])
    end

    it "makes sure automatic groups are visible to logged on users" do
      g = Group.refresh_automatic_group!(:moderators)
      expect(g.visibility_level).to eq(Group.visibility_levels[:logged_on_users])

      tl0 = Group.refresh_automatic_group!(:trust_level_0)
      expect(tl0.visibility_level).to eq(Group.visibility_levels[:logged_on_users])
    end

    it "ensures that the moderators group is messageable by all" do
      group = Group.find(Group::AUTO_GROUPS[:moderators])
      group.update!(messageable_level: Group::ALIAS_LEVELS[:nobody])
      Group.refresh_automatic_group!(:moderators)

      expect(group.reload.messageable_level).to eq(Group::ALIAS_LEVELS[:everyone])
    end

    it "does not reset the localized name" do
      begin
        I18n.locale = SiteSetting.default_locale = 'fi'

        group = Group.find(Group::AUTO_GROUPS[:everyone])
        group.update!(name: I18n.t("groups.default_names.everyone"))

        Group.refresh_automatic_group!(:everyone)

        expect(group.reload.name).to eq(I18n.t("groups.default_names.everyone"))

        I18n.locale = SiteSetting.default_locale = 'en'

        Group.refresh_automatic_group!(:everyone)

        expect(group.reload.name).to eq(I18n.t("groups.default_names.everyone"))
      end
    end

    it "uses the localized name if name has not been taken" do
      begin
        I18n.locale = SiteSetting.default_locale = 'de'

        group = Group.refresh_automatic_group!(:staff)

        expect(group.name).to_not eq('staff')
        expect(group.name).to eq(I18n.t('groups.default_names.staff'))
      end
    end

    it "does not use the localized name if name has already been taken" do
      begin
        I18n.locale = SiteSetting.default_locale = 'de'

        Fabricate(:group, name: I18n.t('groups.default_names.staff').upcase)
        group = Group.refresh_automatic_group!(:staff)
        expect(group.name).to eq('staff')

        Fabricate(:user, username: I18n.t('groups.default_names.moderators').upcase)
        group = Group.refresh_automatic_group!(:moderators)
        expect(group.name).to eq('moderators')
      end
    end

    it "always uses the default locale" do
      SiteSetting.default_locale = "de"
      I18n.locale = "en"

      group = Group.refresh_automatic_group!(:staff)

      expect(group.name).to_not eq('staff')
      expect(group.name).to eq(I18n.t('groups.default_names.staff', locale: "de"))
    end
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
    expect(real_staff.sort).to eq [moderator.id, admin.id].sort

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

    # we need some ninja work to set min username to 6

    User.where('length(username) < 6').each do |u|
      u.username = u.username + "ZZZZZZ"
      u.save!
    end

    SiteSetting.min_username_length = 6
    Group.refresh_automatic_groups!(:staff)
    # should not explode here
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

    expect(Group[:trust_level_2].user_ids).to include(user.id, user2.id)
  end

  it "Correctly updates all automatic groups upon request" do
    admin = Fabricate(:admin)
    user = Fabricate(:user)
    user.change_trust_level!(TrustLevel[2])

    DB.exec("UPDATE groups SET user_count = 0 WHERE id = #{Group::AUTO_GROUPS[:trust_level_2]}")

    Group.refresh_automatic_groups!

    groups = Group.includes(:users).to_a
    expect(groups.count).to eq Group::AUTO_GROUPS.count

    g = groups.find { |grp| grp.id == Group::AUTO_GROUPS[:admins] }
    expect(g.users.count).to eq g.user_count
    expect(g.users.pluck(:id)).to contain_exactly(admin.id)

    g = groups.find { |grp| grp.id == Group::AUTO_GROUPS[:staff] }
    expect(g.users.count).to eq g.user_count
    expect(g.users.pluck(:id)).to contain_exactly(admin.id)

    g = groups.find { |grp| grp.id == Group::AUTO_GROUPS[:trust_level_1] }
    expect(g.users.count).to eq g.user_count
    expect(g.users.pluck(:id)).to contain_exactly(admin.id, user.id)

    g = groups.find { |grp| grp.id == Group::AUTO_GROUPS[:trust_level_2] }
    expect(g.users.count).to eq g.user_count
    expect(g.users.pluck(:id)).to contain_exactly(user.id)
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

  describe 'new' do
    subject { Fabricate.build(:group) }

    it 'triggers a extensibility event' do
      event = DiscourseEvent.track_events { subject.save! }.first

      expect(event[:event_name]).to eq(:group_created)
      expect(event[:params].first).to eq(subject)
    end
  end

  describe 'destroy' do
    fab!(:user) { Fabricate(:user) }
    fab!(:group) { Fabricate(:group, users: [user]) }

    before do
      group.add(user)
    end

    it "it deleted correctly" do
      group.destroy!
      expect(User.where(id: user.id).count).to eq 1
      expect(GroupUser.where(group_id: group.id).count).to eq 0
    end

    it 'triggers a extensibility event' do
      event = DiscourseEvent.track_events { group.destroy! }.first

      expect(event[:event_name]).to eq(:group_destroyed)
      expect(event[:params].first).to eq(group)
    end

    it "strips the user's title and unsets the user's primary group when exact match" do
      group.update(title: 'Awesome')
      user.update(primary_group: group)

      group.destroy!

      user.reload
      expect(user.title).to eq(nil)
      expect(user.primary_group).to eq(nil)
    end

    it "does not strip title or unset primary group when not exact match" do
      primary_group = Fabricate(:group, primary_group: true, title: 'Different')
      primary_group.add(user)
      group.update(title: 'Awesome')

      group.destroy!

      user.reload
      expect(user.title).to eq('Different')
      expect(user.primary_group).to eq(primary_group)
    end
  end

  it "has custom fields" do
    group = Fabricate(:group)
    expect(group.custom_fields["a"]).to be_nil

    group.custom_fields["hugh"] = "jackman"
    group.custom_fields["jack"] = "black"
    group.save

    group = Group.find(group.id)
    expect(group.custom_fields).to eq("hugh" => "jackman", "jack" => "black")
  end

  it "allows you to lookup a new group by name" do
    group = Fabricate(:group)
    expect(group.id).to eq Group[group.name].id
    expect(group.id).to eq Group[group.name.to_sym].id
  end

  it "can find desired groups correctly" do
    expect(Group.desired_trust_level_groups(2).sort).to eq [10, 11, 12]
  end

  it "correctly handles trust level changes" do
    user = Fabricate(:user, trust_level: 2)
    Group.user_trust_level_change!(user.id, 2)

    expect(user.groups.map(&:name).sort).to eq ["trust_level_0", "trust_level_1", "trust_level_2"]

    Group.user_trust_level_change!(user.id, 0)
    user.reload
    expect(user.groups.map(&:name).sort).to eq ["trust_level_0"]
  end

  context "group management" do
    fab!(:group) { Fabricate(:group) }

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

  describe 'trust level management' do
    it "correctly grants a trust level to members" do
      group = Fabricate(:group, grant_trust_level: 2)
      u0 = Fabricate(:user, trust_level: 0)
      u3 = Fabricate(:user, trust_level: 3)

      group.add(u0)
      expect(u0.reload.trust_level).to eq(2)

      group.add(u3)
      expect(u3.reload.trust_level).to eq(3)
    end

    describe 'when a user has qualified for trust level 1' do
      fab!(:user) do
        Fabricate(:user,
          trust_level: 1,
          created_at: Time.zone.now - 10.years
        )
      end

      fab!(:group) { Fabricate(:group, grant_trust_level: 1) }
      fab!(:group2) { Fabricate(:group, grant_trust_level: 0) }

      before do
        user.user_stat.update!(
          topics_entered: 999,
          posts_read_count: 999,
          time_read: 999
        )
      end

      it "should not demote the user" do
        group.add(user)
        group2.add(user)

        expect(user.reload.trust_level).to eq(1)

        group.remove(user)

        expect(user.reload.trust_level).to eq(0)
      end
    end

    it "adjusts the user trust level" do
      g0 = Fabricate(:group, grant_trust_level: 2)
      g1 = Fabricate(:group, grant_trust_level: 3)
      g2 = Fabricate(:group)

      user = Fabricate(:user, trust_level: 0)

      # Add a group without one to consider `NULL` check
      g2.add(user)
      expect(user.group_granted_trust_level).to be_nil
      expect(user.manual_locked_trust_level).to be_nil

      g0.add(user)
      expect(user.reload.trust_level).to eq(2)
      expect(user.group_granted_trust_level).to eq(2)
      expect(user.manual_locked_trust_level).to be_nil

      g1.add(user)
      expect(user.reload.trust_level).to eq(3)
      expect(user.group_granted_trust_level).to eq(3)
      expect(user.manual_locked_trust_level).to be_nil

      g1.remove(user)
      expect(user.reload.trust_level).to eq(2)
      expect(user.group_granted_trust_level).to eq(2)
      expect(user.manual_locked_trust_level).to be_nil

      g0.remove(user)
      user.reload
      expect(user.manual_locked_trust_level).to be_nil
      expect(user.group_granted_trust_level).to be_nil
      expect(user.trust_level).to eq(0)
    end
  end

  it 'should cook the bio' do
    group = Fabricate(:group)
    group.update!(bio_raw: 'This is a group for :unicorn: lovers')

    expect(group.bio_cooked).to include("unicorn.png")

    group.update!(bio_raw: '')

    expect(group.bio_cooked).to eq(nil)
  end

  describe ".visible_groups" do

    def can_view?(user, group)
      Group.visible_groups(user).where(id: group.id).exists?
    end

    it 'correctly restricts group visibility' do
      group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:owners])
      logged_on_user = Fabricate(:user)
      member = Fabricate(:user)
      group.add(member)
      group.save!

      owner = Fabricate(:user)
      group.add_owner(owner)

      moderator = Fabricate(:user, moderator: true)
      admin = Fabricate(:user, admin: true)

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(false)
      expect(can_view?(member, group)).to eq(false)
      expect(can_view?(logged_on_user, group)).to eq(false)
      expect(can_view?(nil, group)).to eq(false)

      group.update_columns(visibility_level: Group.visibility_levels[:staff])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(true)
      expect(can_view?(member, group)).to eq(false)
      expect(can_view?(logged_on_user, group)).to eq(false)
      expect(can_view?(nil, group)).to eq(false)

      group.update_columns(visibility_level: Group.visibility_levels[:members])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(false)
      expect(can_view?(member, group)).to eq(true)
      expect(can_view?(logged_on_user, group)).to eq(false)
      expect(can_view?(nil, group)).to eq(false)

      group.update_columns(visibility_level: Group.visibility_levels[:public])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(true)
      expect(can_view?(member, group)).to eq(true)
      expect(can_view?(logged_on_user, group)).to eq(true)
      expect(can_view?(nil, group)).to eq(true)

      group.update_columns(visibility_level: Group.visibility_levels[:logged_on_users])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(true)
      expect(can_view?(member, group)).to eq(true)
      expect(can_view?(logged_on_user, group)).to eq(true)
      expect(can_view?(nil, group)).to eq(false)
    end

  end

  describe ".members_visible_groups" do

    def can_view?(user, group)
      Group.members_visible_groups(user).exists?(id: group.id)
    end

    it 'correctly restricts group members visibility' do
      group = Fabricate.build(:group, members_visibility_level: Group.visibility_levels[:owners])
      logged_on_user = Fabricate(:user)
      member = Fabricate(:user)
      group.add(member)
      group.save!

      owner = Fabricate(:user)
      group.add_owner(owner)

      moderator = Fabricate(:user, moderator: true)
      admin = Fabricate(:user, admin: true)

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(false)
      expect(can_view?(member, group)).to eq(false)
      expect(can_view?(logged_on_user, group)).to eq(false)
      expect(can_view?(nil, group)).to eq(false)

      group.update_columns(members_visibility_level: Group.visibility_levels[:staff])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(true)
      expect(can_view?(member, group)).to eq(false)
      expect(can_view?(logged_on_user, group)).to eq(false)
      expect(can_view?(nil, group)).to eq(false)

      group.update_columns(members_visibility_level: Group.visibility_levels[:members])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(false)
      expect(can_view?(member, group)).to eq(true)
      expect(can_view?(logged_on_user, group)).to eq(false)
      expect(can_view?(nil, group)).to eq(false)

      group.update_columns(members_visibility_level: Group.visibility_levels[:public])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(true)
      expect(can_view?(member, group)).to eq(true)
      expect(can_view?(logged_on_user, group)).to eq(true)
      expect(can_view?(nil, group)).to eq(true)

      group.update_columns(members_visibility_level: Group.visibility_levels[:logged_on_users])

      expect(can_view?(admin, group)).to eq(true)
      expect(can_view?(owner, group)).to eq(true)
      expect(can_view?(moderator, group)).to eq(true)
      expect(can_view?(member, group)).to eq(true)
      expect(can_view?(logged_on_user, group)).to eq(true)
      expect(can_view?(nil, group)).to eq(false)
    end

  end

  describe '#remove' do
    before { group.add(user) }

    context 'when stripping title' do
      it "only strips user's title if exact match" do
        group.update!(title: 'Awesome')
        expect { group.remove(user) }.to change { user.reload.title }.from('Awesome').to(nil)

        group.add(user)
        user.update_columns(title: 'Different')
        expect { group.remove(user) }.to_not change { user.reload.title }
      end

      it "grants another title when the user has other available titles" do
        group.update!(title: 'Awesome')
        Fabricate(:group, title: 'Super').add(user)

        expect { group.remove(user) }.to change { user.reload.title }.from('Awesome').to('Super')
      end
    end

    it "unsets the user's primary group" do
      user.update(primary_group: group)
      expect { group.remove(user) }.to change { user.reload.primary_group }.from(group).to(nil)
    end

    it 'triggers a user_removed_from_group event' do
      events = DiscourseEvent.track_events { group.remove(user) }.map { |e| e[:event_name] }
      expect(events).to include(:user_removed_from_group)
    end
  end

  describe '#add' do
    it 'grants the title only if the new member does not have title' do
      group.update(title: 'Awesome')
      expect { group.add(user) }.to change { user.reload.title }.from(nil).to('Awesome')

      group.remove(user)
      user.update(title: 'Already Awesome')
      expect { group.add(user) }.not_to change { user.reload.title }
    end

    it "always sets user's primary group" do
      group.update(primary_group: true, title: 'AAAA')
      expect { group.add(user) }.to change { user.reload.primary_group }.from(nil).to(group)

      new_group = Fabricate(:group, primary_group: true, title: 'BBBB')

      expect {
        new_group.add(user)
        user.reload
      }.to change { user.primary_group }.from(group).to(new_group)
        .and change { user.title }.from('AAAA').to('BBBB')
    end

    it "can send a notification to the user" do
      expect { group.add(user, notify: true) }.to change { Notification.count }.by(1)

      notification = Notification.last
      expect(notification.notification_type).to eq(Notification.types[:membership_request_accepted])
      expect(notification.user_id).to eq(user.id)
    end

    it 'triggers a user_added_to_group event' do
      begin
        automatic = nil
        called = false

        DiscourseEvent.on(:user_added_to_group) do |_u, _g, options|
          automatic = options[:automatic]
          called = true
        end

        group.add(user)

        expect(automatic).to eql(false)
        expect(called).to eq(true)
      ensure
        DiscourseEvent.off(:user_added_to_group)
      end
    end

    context 'when adding a user into a public group' do
      fab!(:category) { Fabricate(:category) }

      it "should publish the group's categories to the client" do
        group.update!(public_admission: true, categories: [category])

        message = MessageBus.track_publish("/categories") { group.add(user) }.first

        expect(message.data[:categories].count).to eq(1)
        expect(message.data[:categories].first[:id]).to eq(category.id)
        expect(message.user_ids).to eq([user.id])
      end

      describe "when group belongs to more than #{Group::PUBLISH_CATEGORIES_LIMIT} categories" do
        it "should publish a message to refresh the user's client" do
          (Group::PUBLISH_CATEGORIES_LIMIT + 1).times do
            group.categories << Fabricate(:category)
          end

          message = MessageBus.track_publish { group.add(user) }.first

          expect(message.data).to eq('clobber')
          expect(message.channel).to eq('/refresh_client')
          expect(message.user_ids).to eq([user.id])
        end
      end
    end
  end

  describe '.search_groups' do
    fab!(:group) { Fabricate(:group, name: 'tEsT_more_things', full_name: 'Abc something awesome') }

    it 'should return the right groups' do
      group

      expect(Group.search_groups('te')).to eq([group])
      expect(Group.search_groups('TE')).to eq([group])
      expect(Group.search_groups('es')).to eq([group])
      expect(Group.search_groups('ES')).to eq([group])
      expect(Group.search_groups('ngs')).to eq([group])
      expect(Group.search_groups('sOmEthi')).to eq([group])
      expect(Group.search_groups('abc')).to eq([group])
      expect(Group.search_groups('sOmEthi')).to eq([group])
      expect(Group.search_groups('test2')).to eq([])
    end
  end

  describe '#bulk_add' do
    it 'should be able to add multiple users' do
      group.bulk_add([user.id, admin.id])

      expect(group.group_users.map(&:user_id)).to contain_exactly(user.id, admin.id)
    end

    it 'updates group user count' do
      expect {
        group.bulk_add([user.id, admin.id])
        group.reload
      }.to change { group.user_count }.by(2)
    end
  end

  it "Correctly updates has_messages" do
    group = Fabricate(:group, has_messages: true)
    topic = Fabricate(:private_message_topic)

    # when group message is not present
    Group.refresh_has_messages!
    group.reload
    expect(group.has_messages?).to eq false

    # when group message is present
    group.update!(has_messages: true)
    TopicAllowedGroup.create!(topic_id: topic.id, group_id: group.id)
    Group.refresh_has_messages!
    group.reload
    expect(group.has_messages?).to eq true
  end

  describe '#automatic_group_membership' do
    describe 'for a automatic_membership_retroactive group' do
      let(:group) { Fabricate(:group, automatic_membership_retroactive: true) }

      it "should be triggered on create and update" do
        expect { group }
          .to change { Jobs::AutomaticGroupMembership.jobs.size }.by(1)

        job = Jobs::AutomaticGroupMembership.jobs.last

        expect(job["args"].first["group_id"]).to eq(group.id)

        Jobs::AutomaticGroupMembership.jobs.clear

        expect do
          group.update!(name: 'asdiaksjdias')
        end.to change { Jobs::AutomaticGroupMembership.jobs.size }.by(1)

        job = Jobs::AutomaticGroupMembership.jobs.last

        expect(job["args"].first["group_id"]).to eq(group.id)
      end
    end
  end

  it "allows Font Awesome 4.7 syntax as group avatar flair" do
    group = Fabricate(:group)
    group.flair_url = "fa-air-freshener"
    group.save

    group = Group.find(group.id)
    expect(group.flair_url).to eq("fa-air-freshener")
  end

  it "allows Font Awesome 5 syntax as group avatar flair" do
    group = Fabricate(:group)
    group.flair_url = "fab fa-bandcamp"
    group.save

    group = Group.find(group.id)
    expect(group.flair_url).to eq("fab fa-bandcamp")
  end

  context "Unicode usernames and group names" do
    before { SiteSetting.unicode_usernames = true }

    it "should normalize the name" do
      group = Fabricate(:group, name: "Bücherwurm") # NFD
      expect(group.name).to eq("Bücherwurm") # NFC
    end
  end
end
