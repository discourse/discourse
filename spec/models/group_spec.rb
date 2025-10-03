# frozen_string_literal: true

RSpec.describe Group do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }

  it_behaves_like "it has custom fields"

  describe "Validations" do
    it { is_expected.to validate_length_of(:bio_raw).is_at_most(3000) }
    it { is_expected.to validate_length_of(:membership_request_template).is_at_most(5000) }
    it { is_expected.to validate_length_of(:full_name).is_at_most(100) }

    describe "#grant_trust_level" do
      describe "when trust level is not valid" do
        it "should not be valid" do
          group.grant_trust_level = 123_456

          expect(group.valid?).to eq(false)

          expect(group.errors.full_messages.join(",")).to eq(
            I18n.t("groups.errors.grant_trust_level_not_valid", trust_level: 123_456),
          )
        end
      end
    end

    describe "#name" do
      context "when a user with a similar name exists" do
        it "should not be valid" do
          new_group = Fabricate.build(:group, name: admin.username.upcase)

          expect(new_group).to_not be_valid

          expect(new_group.errors.full_messages.first).to include(
            I18n.t("activerecord.errors.messages.taken"),
          )
        end
      end

      context "when a group with a similar name exists" do
        it "should not be valid" do
          new_group = Fabricate.build(:group, name: group.name.upcase)

          expect(new_group).to_not be_valid

          expect(new_group.errors.full_messages.first).to include(
            I18n.t("activerecord.errors.messages.taken"),
          )
        end
      end

      context "when a group with a reserved name is created" do
        it "should not be valid" do
          new_group = Fabricate.build(:group, name: "by-id")
          expect(new_group).to_not be_valid

          expect(new_group.errors.full_messages.first).to include(
            I18n.t("activerecord.errors.messages.reserved", name: "by-id"),
          )
        end
      end
    end
  end

  describe ".human_users" do
    before { group.users << user << Discourse.system_user }

    it "returns only human users" do
      expect(group.human_users).to contain_exactly(user)
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

    it "filters results by datetime using the before parameter" do
      p1 = Fabricate(:post)
      p2 = Fabricate(:post, created_at: p1.created_at + 2.minute)
      group.add(p1.user)

      posts = group.posts_for(Guardian.new, before: p1.created_at + 1.minute)
      expect(posts).to include(p1)
      expect(posts).not_to include(p2)
    end
  end

  describe "#set_message_default_notification_levels!" do
    context "with too many users in a group" do
      fab!(:topic)
      fab!(:large_group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]) }

      before do
        SiteSetting.group_pm_user_limit = 1
        Fabricate.times(2, :user).each { |user| large_group.add(user) }
      end

      it "raises a GroupPmUserLimitExceededError error" do
        expect do
          large_group.reload.set_message_default_notification_levels!(topic)
        end.to raise_error(
          Group::GroupPmUserLimitExceededError,
          I18n.t(
            "groups.errors.default_notification_level_users_limit",
            count: SiteSetting.group_pm_user_limit,
            group_name: large_group.name,
          ),
        )
      end
    end
  end

  describe "#builtin" do
    context "when verifying enum sequence" do
      it "'moderators' should be at 1st position" do
        expect(described_class.builtin[:moderators]).to eq(1)
      end

      it "'trust_level_2' should be at 4th position" do
        expect(described_class.builtin[:trust_level_2]).to eq(4)
      end
    end
  end

  # UGLY but perf is horrible with this callback
  before { User.set_callback(:create, :after, :ensure_in_trust_level_group) }
  after { User.skip_callback(:create, :after, :ensure_in_trust_level_group) }

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

    it "strips trailing and leading spaces" do
      group.name = "  dragon  "

      expect(group.save).to eq(true)
      expect(group.reload.name).to eq("dragon")
    end

    it "is invalid for case-insensitive existing names" do
      build(:group, name: "this_is_a_name").save
      group.name = "This_Is_A_Name"
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

    it "is invalid for too many domains" do
      SiteSetting.max_automatic_membership_email_domains = 1
      group.automatic_membership_email_domains = "discourse.org|wikipedia.org"
      expect(group).not_to be_valid
    end

    it "is invalid for too abnormally long domains" do
      group.automatic_membership_email_domains = "#{"d" * 253}.org"
      expect(group).not_to be_valid
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

    context "when a group has no owners" do
      describe "group has not been persisted" do
        it "should not allow membership requests" do
          group = Fabricate.build(:group, allow_membership_requests: true)

          expect(group.valid?).to eq(false)

          expect(group.errors.full_messages).to include(
            I18n.t("groups.errors.cant_allow_membership_requests"),
          )

          group.group_users.build(user_id: user.id, owner: true)

          expect(group.valid?).to eq(true)
        end
      end

      it "should not allow membership requests" do
        group.allow_membership_requests = true

        expect(group.valid?).to eq(false)

        expect(group.errors.full_messages).to include(
          I18n.t("groups.errors.cant_allow_membership_requests"),
        )

        group.allow_membership_requests = false
        group.save!

        group.add_owner(user)
        group.allow_membership_requests = true

        expect(group.valid?).to eq(true)
      end
    end
  end

  describe "#primary_group=" do
    before { group.add(user) }

    it "updates all members' #primary_group" do
      expect { group.update(primary_group: true) }.to change { user.reload.primary_group }.from(
        nil,
      ).to(group)
      expect { group.update(primary_group: false) }.to change { user.reload.primary_group }.from(
        group,
      ).to(nil)
    end

    it "updates all members' #flair_group" do
      expect { group.update(primary_group: true) }.to change { user.reload.flair_group }.from(
        nil,
      ).to(group)
      expect { group.update(primary_group: false) }.to change { user.reload.flair_group }.from(
        group,
      ).to(nil)
    end
  end

  describe "#title=" do
    it "updates the member's title only if it was blank or exact match" do
      group.add(user)

      expect { group.update(title: "Awesome") }.to change { user.reload.title }.from(nil).to(
        "Awesome",
      )
      expect { group.update(title: "Super") }.to change { user.reload.title }.from("Awesome").to(
        "Super",
      )

      user.update(title: "Differently Awesome")
      expect { group.update(title: "Awesome") }.to_not change { user.reload.title }
    end

    it "doesn't update non-member's title" do
      user.update(title: group.title)
      expect { group.update(title: "Super") }.to_not change { user.reload.title }
    end
  end

  describe ".auto_groups_between" do
    it "returns the auto groups between lower and upper bounds" do
      expect(
        described_class.auto_groups_between(:trust_level_0, :trust_level_3),
      ).to contain_exactly(10, 11, 12, 13)
    end

    it "excludes the undefined groups between staff and TL0" do
      expect(described_class.auto_groups_between(:admins, :trust_level_0)).to contain_exactly(
        1,
        2,
        3,
        10,
      )
    end

    it "returns an empty array when lower group is higher than upper group" do
      expect(described_class.auto_groups_between(:trust_level_1, :trust_level_0)).to be_empty
    end

    it "returns an empty array when passing an unknown group" do
      expect(described_class.auto_groups_between(:trust_level_0, :trust_level_1337)).to be_empty
    end
  end

  describe ".refresh_automatic_group!" do
    it "does not include staged users in any automatic groups" do
      staged = Fabricate(:staged, trust_level: 1)

      Group.refresh_automatic_group!(:trust_level_0)
      Group.refresh_automatic_group!(:trust_level_1)

      expect(GroupUser.where(user_id: staged.id).count).to eq(0)

      staged.unstage!

      expect(GroupUser.where(user_id: staged.id).count).to eq(2)
    end

    describe "after updating automatic group members" do
      fab!(:user)

      it "triggers an event when a user is removed from an automatic group" do
        tl3_users = Group.find(Group::AUTO_GROUPS[:trust_level_3])
        tl3_users.add(user)

        _events = DiscourseEvent.track_events { Group.refresh_automatic_group!(:trust_level_3) }

        expect(GroupUser.exists?(group: tl3_users, user: user)).to eq(false)
        publish_event_job_args = Jobs::PublishGroupMembershipUpdates.jobs.last["args"].first
        expect(publish_event_job_args["user_ids"]).to include(user.id)
        expect(publish_event_job_args["group_id"]).to eq(tl3_users.id)
        expect(publish_event_job_args["type"]).to include("remove")
      end

      it "triggers an event when a user is added to an automatic group" do
        tl0_users = Group.find(Group::AUTO_GROUPS[:trust_level_0])

        expect(GroupUser.exists?(group: tl0_users, user: user)).to eq(false)

        events = DiscourseEvent.track_events { Group.refresh_automatic_group!(:trust_level_0) }

        expect(events).to include(event_name: :group_updated, params: [tl0_users])
        expect(GroupUser.exists?(group: tl0_users, user: user)).to eq(true)
        publish_event_job_args = Jobs::PublishGroupMembershipUpdates.jobs.last["args"].first
        expect(publish_event_job_args["user_ids"]).to include(user.id)
        expect(publish_event_job_args["group_id"]).to eq(tl0_users.id)
        expect(publish_event_job_args["type"]).to eq("add")
      end
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
        I18n.locale = SiteSetting.default_locale = "fi"

        group = Group.find(Group::AUTO_GROUPS[:everyone])
        group.update!(name: I18n.t("groups.default_names.everyone"))

        Group.refresh_automatic_group!(:everyone)

        expect(group.reload.name).to eq(I18n.t("groups.default_names.everyone"))

        I18n.locale = SiteSetting.default_locale = "en"

        Group.refresh_automatic_group!(:everyone)

        expect(group.reload.name).to eq(I18n.t("groups.default_names.everyone"))
      end
    end

    it "uses the localized name if name has not been taken" do
      begin
        I18n.locale = SiteSetting.default_locale = "de"

        group = Group.refresh_automatic_group!(:staff)

        expect(group.name).to_not eq("staff")
        expect(group.name).to eq(I18n.t("groups.default_names.staff"))
      end
    end

    it "does not use the localized name if name has already been taken" do
      begin
        I18n.locale = SiteSetting.default_locale = "de"

        Fabricate(:group, name: I18n.t("groups.default_names.staff").upcase)
        group = Group.refresh_automatic_group!(:staff)
        expect(group.name).to eq("staff")

        Fabricate(:user, username: I18n.t("groups.default_names.moderators").upcase)
        group = Group.refresh_automatic_group!(:moderators)
        expect(group.name).to eq("moderators")
      end
    end

    it "always uses the default locale" do
      SiteSetting.default_locale = "de"
      I18n.locale = "en"

      group = Group.refresh_automatic_group!(:staff)

      expect(group.name).to_not eq("staff")
      expect(group.name).to eq(I18n.t("groups.default_names.staff", locale: "de"))
    end

    it "can save groups" do
      # Update all short usernames to ensure that the future minimum username
      # length is met for all existing usernames
      User.find_each { |u| u.update!(username: u.username * 2) }

      # This a corner case when a group has a short name that is technically no
      # longer allowed by `min_username_length`
      Group.find(Group::AUTO_GROUPS[:everyone]).update!(name: "all")
      SiteSetting.min_username_length = 10

      expect { Group.refresh_automatic_groups! }.not_to raise_error
    end
  end

  it "Correctly handles removal of primary group" do
    group = Fabricate(:group, flair_icon: "icon")
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
    expect(user.flair_group_id).to eq nil
  end

  it "Can update moderator/staff/admin groups correctly" do
    admin = Fabricate(:admin)
    moderator = Fabricate(:moderator)

    Group.refresh_automatic_groups!(:admins, :staff, :moderators)

    expect(Group[:admins].human_users).to contain_exactly(admin)
    expect(Group[:moderators].human_users).to contain_exactly(moderator)
    expect(Group[:staff].human_users).to contain_exactly(moderator, admin)

    admin.admin = false
    admin.save

    Group.refresh_automatic_group!(:admins)
    expect(Group[:admins].human_users).to be_empty

    moderator.revoke_moderation!

    admin.grant_admin!
    expect(Group[:admins].human_users).to contain_exactly(admin)
    expect(Group[:staff].human_users).to contain_exactly(admin)

    admin.revoke_admin!
    expect(Group[:admins].human_users).to be_empty
    expect(Group[:staff].human_users).to be_empty

    admin.grant_moderation!
    expect(Group[:moderators].human_users).to contain_exactly(admin)
    expect(Group[:staff].human_users).to contain_exactly(admin)

    admin.revoke_moderation!
    expect(Group[:admins].human_users).to be_empty
    expect(Group[:staff].human_users).to be_empty

    # we need some work to set min username to 6

    User
      .where("length(username) < 6")
      .each do |u|
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

    Group.delete_all
    Group.refresh_automatic_groups!

    expect(Group.count).to eq Group::AUTO_GROUPS.count

    g = Group[:admins]
    expect(g.human_users.count).to eq(g.user_count)
    expect(g.human_users).to contain_exactly(admin)

    g = Group[:admins]
    expect(g.human_users.count).to eq(g.user_count)
    expect(g.human_users).to contain_exactly(admin)

    g = Group[:trust_level_1]
    expect(g.human_users.count).to eq(g.user_count)
    expect(g.human_users).to contain_exactly(admin, user)

    g = Group[:trust_level_2]
    expect(g.human_users.count).to eq(g.user_count)
    expect(g.human_users).to contain_exactly(admin, user)
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

  describe "new" do
    subject(:group) { Fabricate.build(:group) }

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events { group.save! }.first

      expect(event[:event_name]).to eq(:group_created)
      expect(event[:params].first).to eq(group)
    end
  end

  describe "destroy" do
    fab!(:user)
    fab!(:group) { Fabricate(:group, users: [user]) }

    before { group.add(user) }

    it "it deleted correctly" do
      group.destroy!
      expect(User.where(id: user.id).count).to eq 1
      expect(GroupUser.where(group_id: group.id).count).to eq 0
    end

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events { group.destroy! }.first

      expect(event[:event_name]).to eq(:group_destroyed)
      expect(event[:params].first).to eq(group)
    end

    it "strips the user's title and unsets the user's primary group when exact match" do
      group.update(title: "Awesome")
      user.update(primary_group: group)

      group.destroy!

      user.reload
      expect(user.title).to eq(nil)
      expect(user.primary_group).to eq(nil)
    end

    it "does not strip title or unset primary group when not exact match" do
      primary_group = Fabricate(:group, primary_group: true, title: "Different")
      primary_group.add(user)
      group.update(title: "Awesome")

      group.destroy!

      user.reload
      expect(user.title).to eq("Different")
      expect(user.primary_group).to eq(primary_group)
    end

    it "doesn't fail when the user gets destroyed" do
      group.update(title: "Awesome")
      group.add(user)
      user.reload

      UserDestroyer.new(Discourse.system_user).destroy(user)
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

  it "allows you to lookup a group by integer id" do
    group = Fabricate(:group)
    expect(Group.lookup_groups(group_ids: group.id)).to contain_exactly(group)
  end

  it "allows you to lookup groups by comma separated string" do
    group1 = Fabricate(:group)
    group2 = Fabricate(:group)
    expect(Group.lookup_groups(group_ids: "#{group1.id},#{group2.id}")).to contain_exactly(
      group1,
      group2,
    )
  end

  it "allows you to lookup groups by array" do
    group1 = Fabricate(:group)
    group2 = Fabricate(:group)
    expect(Group.lookup_groups(group_ids: [group1.id, group2.id])).to contain_exactly(
      group1,
      group2,
    )
  end

  it "can find desired groups correctly" do
    expect(Group.desired_trust_level_groups(2)).to contain_exactly(10, 11, 12)
  end

  it "correctly handles trust level changes" do
    user = Fabricate(:user, trust_level: 2)
    Group.user_trust_level_change!(user.id, 2)

    expect(user.groups.map(&:name)).to match_array %w[trust_level_0 trust_level_1 trust_level_2]

    Group.user_trust_level_change!(user.id, 0)
    user.reload
    expect(user.groups.map(&:name)).to contain_exactly("trust_level_0")
  end

  it "generates an event when applying group from trust level change" do
    called = nil
    block = Proc.new { |user, group| called = { user_id: user.id, group_id: group.id } }

    begin
      DiscourseEvent.on(:user_added_to_group, &block)

      user = Fabricate(:user, trust_level: 2)
      Group.user_trust_level_change!(user.id, 2)

      expect(called).to eq(user_id: user.id, group_id: Group.find_by(name: "trust_level_2").id)
    ensure
      DiscourseEvent.off(:user_added_to_group, &block)
    end
  end

  describe "group management" do
    fab!(:group)

    it "by default has no managers" do
      expect(group.group_users.where("group_users.owner")).to be_empty
    end

    it "multiple managers can be appointed" do
      2.times do |i|
        u = Fabricate(:user)
        group.add_owner(u)
      end
      expect(group.group_users.where("group_users.owner").count).to eq(2)
    end

    it "manager has authority to edit membership" do
      u = Fabricate(:user)
      expect(Guardian.new(u).can_edit?(group)).to be_falsy
      group.add_owner(u)
      expect(Guardian.new(u).can_edit?(group)).to be_truthy
    end
  end

  describe "trust level management" do
    it "correctly grants a trust level to members" do
      group = Fabricate(:group, grant_trust_level: 2)
      u0 = Fabricate(:user, trust_level: 0)
      u3 = Fabricate(:user, trust_level: 3)

      group.add(u0)
      expect(u0.reload.trust_level).to eq(2)

      group.add(u3)
      expect(u3.reload.trust_level).to eq(3)
    end

    describe "when a user has qualified for trust level 1" do
      fab!(:user) { Fabricate(:user, trust_level: 1, created_at: Time.zone.now - 10.years) }

      fab!(:group) { Fabricate(:group, grant_trust_level: 3) }
      fab!(:group2) { Fabricate(:group, grant_trust_level: 2) }

      before { user.user_stat.update!(topics_entered: 999, posts_read_count: 999, time_read: 999) }

      it "should not demote the user" do
        group.add(user)
        group2.add(user)

        expect(user.reload.trust_level).to eq(3)

        group.remove(user)

        expect(user.reload.trust_level).to eq(2)

        group2.remove(user)

        expect(user.reload.trust_level).to eq(1)
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

  it "should cook the bio" do
    group = Fabricate(:group)
    group.update!(bio_raw: "This is a group for :unicorn: lovers")

    expect(group.bio_cooked).to include("unicorn.png")

    group.update!(bio_raw: "")

    expect(group.bio_cooked).to eq(nil)
  end

  describe ".visible_groups" do
    def can_view?(user, group)
      Group.visible_groups(user).where(id: group.id).exists?
    end

    it "includes everyone group when option is present" do
      expect(
        Group
          .visible_groups(admin, [], include_everyone: true)
          .where(id: Group::AUTO_GROUPS[:everyone])
          .exists?,
      ).to eq(true)
    end

    it "doesn't include everyones group by default" do
      expect(
        Group
          .visible_groups(admin, [], include_everyone: false)
          .where(id: Group::AUTO_GROUPS[:everyone])
          .exists?,
      ).to eq(false)

      expect(
        Group.visible_groups(admin, [], nil).where(id: Group::AUTO_GROUPS[:everyone]).exists?,
      ).to eq(false)

      expect(
        Group.visible_groups(admin, [], {}).where(id: Group::AUTO_GROUPS[:everyone]).exists?,
      ).to eq(false)
    end

    it "correctly restricts group visibility" do
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

      group.add_owner(moderator)

      expect(can_view?(moderator, group)).to eq(true)

      GroupUser.delete_by(group: group, user: moderator)
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
      expect(can_view?(moderator, group)).to eq(true)
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

    it "correctly restricts group members visibility" do
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

      group.add_owner(moderator)

      expect(can_view?(moderator, group)).to eq(true)

      GroupUser.delete_by(group: group, user: moderator)
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
      expect(can_view?(moderator, group)).to eq(true)
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

  describe "#remove" do
    before { group.add(user) }

    context "when stripping title" do
      it "only strips user's title if exact match" do
        group.update!(title: "Awesome")
        expect { group.remove(user) }.to change { user.reload.title }.from("Awesome").to(nil)

        group.add(user)
        user.update_columns(title: "Different")
        expect { group.remove(user) }.to_not change { user.reload.title }
      end

      it "grants another title when the user has other available titles" do
        group.update!(title: "Awesome")
        Fabricate(:group, title: "Super").add(user)

        expect { group.remove(user) }.to change { user.reload.title }.from("Awesome").to("Super")
      end
    end

    it "unsets the user's primary group" do
      user.update(primary_group: group)
      expect { group.remove(user) }.to change { user.reload.primary_group }.from(group).to(nil)
    end

    it "triggers a user_removed_from_group event" do
      events = DiscourseEvent.track_events { group.remove(user) }.map { |e| e[:event_name] }
      expect(events).to include(:user_removed_from_group)
    end

    describe "with webhook" do
      fab!(:group_user_web_hook)

      it "Enqueues webhook events" do
        group.remove(user)
        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

        expect(job_args["event_name"]).to eq("user_removed_from_group")
        payload = JSON.parse(job_args["payload"])
        expect(payload["group_id"]).to eq(group.id)
        expect(payload["user_id"]).to eq(user.id)
      end
    end
  end

  describe "#add" do
    it "grants the title only if the new member does not have title" do
      group.update(title: "Awesome")
      expect { group.add(user) }.to change { user.reload.title }.from(nil).to("Awesome")

      group.remove(user)
      user.update(title: "Already Awesome")
      expect { group.add(user) }.not_to change { user.reload.title }
    end

    it "always sets user's primary group" do
      group.update(primary_group: true, title: "AAAA")
      expect { group.add(user) }.to change { user.reload.primary_group }.from(nil).to(group)

      new_group = Fabricate(:group, primary_group: true, title: "BBBB")

      expect {
        new_group.add(user)
        user.reload
      }.to change { user.primary_group }.from(group).to(new_group).and change { user.title }.from(
              "AAAA",
            ).to("BBBB")
    end

    it "can send a notification to the user" do
      expect { group.add(user, notify: true) }.to change { Notification.count }.by(1)

      notification = Notification.last
      expect(notification.notification_type).to eq(Notification.types[:membership_request_accepted])
      expect(notification.user_id).to eq(user.id)
    end

    it "triggers a user_added_to_group event" do
      automatic = nil
      called = false

      block =
        Proc.new do |_u, _g, options|
          automatic = options[:automatic]
          called = true
        end
      begin
        DiscourseEvent.on(:user_added_to_group, &block)

        group.add(user)

        expect(automatic).to eql(false)
        expect(called).to eq(true)
      ensure
        DiscourseEvent.off(:user_added_to_group, &block)
      end
    end

    context "when adding a user into a public group" do
      fab!(:category)

      it "should publish the group's categories to the client" do
        group.update!(public_admission: true, categories: [category])

        message = MessageBus.track_publish("/categories") { group.add(user) }.first

        expect(message.data[:categories].count).to eq(1)
        expect(message.data[:categories].first[:id]).to eq(category.id)
        expect(message.user_ids).to eq([user.id])
      end

      describe "when group belongs to more than #{Group::PUBLISH_CATEGORIES_LIMIT} categories" do
        it "should publish a message to refresh the user's client" do
          (Group::PUBLISH_CATEGORIES_LIMIT + 1).times { group.categories << Fabricate(:category) }

          message = MessageBus.track_publish { group.add(user) }.first

          expect(message.data).to eq("clobber")
          expect(message.channel).to eq("/refresh_client")
          expect(message.user_ids).to eq([user.id])
        end
      end
    end
  end

  describe ".search_groups" do
    def search_group_names(name)
      Group.search_groups(name, sort: :auto).map(&:name)
    end

    it "should return the right groups" do
      Group.delete_all

      group_name =
        Fabricate(:group, name: "tEsT_more_things", full_name: "Abc something awesome").name

      expect(search_group_names("te")).to eq([group_name])
      expect(search_group_names("TE")).to eq([group_name])
      expect(search_group_names("es")).to eq([group_name])
      expect(search_group_names("ES")).to eq([group_name])
      expect(search_group_names("ngs")).to eq([group_name])
      expect(search_group_names("sOmEthi")).to eq([group_name])
      expect(search_group_names("abc")).to eq([group_name])
      expect(search_group_names("sOmEthi")).to eq([group_name])
      expect(search_group_names("test2")).to eq([])
    end

    it "should prioritize prefix matches on group's name or fullname" do
      Fabricate(:group, name: "pears_11", full_name: "fred apple")
      Fabricate(:group, name: "apples", full_name: "jane orange")
      Fabricate(:group, name: "oranges2", full_name: "nothing")
      Fabricate(:group, name: "oranges1", full_name: "ms fred")

      expect(search_group_names("ap")).to eq(%w[apples pears_11])
      expect(search_group_names("fr")).to eq(%w[pears_11 oranges1])
      expect(search_group_names("oran")).to eq(%w[oranges1 oranges2 apples])

      expect(search_group_names("pearsX11")).to eq([])
    end
  end

  describe "#bulk_add" do
    it "should be able to add multiple users" do
      group.bulk_add([user.id, admin.id])

      expect(group.group_users.map(&:user_id)).to contain_exactly(user.id, admin.id)
    end

    it "updates group user count" do
      expect {
        group.bulk_add([user.id, admin.id])
        group.reload
      }.to change { group.user_count }.from(0).to(2)
    end
  end

  describe "#bulk_remove" do
    it "removes multiple users from the group and doesn't error with user_ids not present" do
      group.bulk_add([user.id, admin.id])

      group.bulk_remove([user.id, admin.id, admin.id + 1])

      expect(group.group_users.count).to be_zero
    end

    it "updates group user count" do
      group.bulk_add([user.id, admin.id])
      expect(group.reload.user_count).to eq(2)

      group.bulk_remove([user.id, admin.id])
      expect(group.reload.user_count).to eq(0)
    end

    describe "with webhook" do
      fab!(:group_user_web_hook)

      it "Enqueues user_removed_from_group webhook events for each group_user" do
        group.bulk_add([user.id, admin.id])

        group.bulk_remove([user.id, admin.id])
        Jobs::EmitWebHookEvent
          .jobs
          .last(2)
          .each do |event|
            job_args = event["args"].first
            expect(job_args["event_name"]).to eq("user_removed_from_group")
            payload = JSON.parse(job_args["payload"])
            expect(payload["group_id"]).to eq(group.id)
            expect([user.id, admin.id]).to include(payload["user_id"])
          end
      end
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

  describe "#automatic_group_membership" do
    let(:group) { Fabricate(:group, automatic_membership_email_domains: "example.com") }

    it "should be triggered on create and update" do
      expect { group }.to change { Jobs::AutomaticGroupMembership.jobs.size }.by(1)

      job = Jobs::AutomaticGroupMembership.jobs.last

      expect(job["args"].first["group_id"]).to eq(group.id)

      Jobs::AutomaticGroupMembership.jobs.clear

      expect do group.update!(name: "asdiaksjdias") end.to change {
        Jobs::AutomaticGroupMembership.jobs.size
      }.by(1)

      job = Jobs::AutomaticGroupMembership.jobs.last

      expect(job["args"].first["group_id"]).to eq(group.id)
    end
  end

  describe "IMAP" do
    let(:group) { Fabricate(:group) }
    let(:mocked_imap_provider) do
      MockedImapProvider.new(
        group.imap_server,
        port: group.imap_port,
        ssl: group.imap_ssl,
        username: group.email_username,
        password: group.email_password,
      )
    end

    def mock_imap
      Imap::Providers::Detector.stubs(:init_with_detected_provider).returns(mocked_imap_provider)
    end

    def configure_imap
      group.update(
        imap_server: "imap.gmail.com",
        imap_port: 993,
        imap_ssl: true,
        imap_enabled: true,
        email_username: "test@gmail.com",
        email_password: "testPassword1!",
      )
    end

    def enable_imap
      SiteSetting.enable_imap = true
      mocked_imap_provider.stubs(:connect!)
      mocked_imap_provider.stubs(:list_mailboxes_with_attributes).returns(
        [stub(attr: [], name: "Inbox")],
      )
      mocked_imap_provider.stubs(:list_mailboxes).returns(["Inbox"])
      mocked_imap_provider.stubs(:disconnect!)
    end

    before { Discourse.redis.del("group_imap_mailboxes_#{group.id}") }

    describe "#imap_mailboxes" do
      it "returns an empty array if group imap is not configured" do
        expect(group.imap_mailboxes).to eq([])
      end

      it "returns an empty array and does not contact IMAP server if group imap is configured but the setting is disabled" do
        configure_imap
        Imap::Providers::Detector.expects(:init_with_detected_provider).never
        expect(group.imap_mailboxes).to eq([])
      end

      it "logs the imap error if one occurs" do
        configure_imap
        mock_imap
        SiteSetting.enable_imap = true
        mocked_imap_provider.stubs(:connect!).raises(Net::IMAP::NoResponseError)
        group.imap_mailboxes
        expect(group.reload.imap_last_error).not_to eq(nil)
      end

      it "returns a list of mailboxes from the IMAP provider" do
        configure_imap
        mock_imap
        enable_imap
        expect(group.imap_mailboxes).to eq(["Inbox"])
      end

      it "caches the login and mailbox fetch" do
        configure_imap
        mock_imap
        enable_imap
        group.imap_mailboxes
        Imap::Providers::Detector.expects(:init_with_detected_provider).never
        group.imap_mailboxes
      end
    end
  end

  describe "Unicode usernames and group names" do
    before { SiteSetting.unicode_usernames = true }

    it "should normalize the name" do
      group = Fabricate(:group, name: "Bücherwurm") # NFD
      expect(group.name).to eq("Bücherwurm") # NFC
    end
  end

  describe "default notifications" do
    let(:category1) { Fabricate(:category) }
    let(:category2) { Fabricate(:category) }
    let(:category3) { Fabricate(:category) }
    let(:category4) { Fabricate(:category) }
    let(:tag1) { Fabricate(:tag) }
    let(:tag2) { Fabricate(:tag) }
    let(:tag3) { Fabricate(:tag) }
    let(:tag4) { Fabricate(:tag) }
    let(:synonym1) { Fabricate(:tag, target_tag: tag1) }
    let(:synonym2) { Fabricate(:tag, target_tag: tag2) }

    it "can set category notifications" do
      group.watching_category_ids = [category1.id, category2.id]
      group.tracking_category_ids = [category3.id]
      group.regular_category_ids = [category4.id]
      group.save!
      expect(
        GroupCategoryNotificationDefault.lookup(group, :watching).pluck(:category_id),
      ).to contain_exactly(category1.id, category2.id)
      expect(GroupCategoryNotificationDefault.lookup(group, :tracking).pluck(:category_id)).to eq(
        [category3.id],
      )
      expect(GroupCategoryNotificationDefault.lookup(group, :regular).pluck(:category_id)).to eq(
        [category4.id],
      )

      new_group = Fabricate.build(:group)
      new_group.watching_category_ids = [category1.id, category2.id]
      new_group.save!
      expect(
        GroupCategoryNotificationDefault.lookup(new_group, :watching).pluck(:category_id),
      ).to contain_exactly(category1.id, category2.id)
    end

    it "can remove categories" do
      [category1, category2].each do |category|
        GroupCategoryNotificationDefault.create!(
          group: group,
          category: category,
          notification_level: GroupCategoryNotificationDefault.notification_levels[:watching],
        )
      end

      group.watching_category_ids = [category2.id]
      group.save!
      expect(GroupCategoryNotificationDefault.lookup(group, :watching).pluck(:category_id)).to eq(
        [category2.id],
      )

      group.watching_category_ids = []
      group.save!
      expect(
        GroupCategoryNotificationDefault.lookup(group, :watching).pluck(:category_id),
      ).to be_empty
    end

    it "can set tag notifications" do
      group.regular_tags = [tag4.name]
      group.watching_tags = [tag1.name, tag2.name]
      group.tracking_tags = [tag3.name]
      group.save!
      expect(GroupTagNotificationDefault.lookup(group, :regular).pluck(:tag_id)).to eq([tag4.id])
      expect(
        GroupTagNotificationDefault.lookup(group, :watching).pluck(:tag_id),
      ).to contain_exactly(tag1.id, tag2.id)
      expect(GroupTagNotificationDefault.lookup(group, :tracking).pluck(:tag_id)).to eq([tag3.id])

      new_group = Fabricate.build(:group)
      new_group.watching_first_post_tags = [tag1.name, tag3.name]
      new_group.save!
      expect(
        GroupTagNotificationDefault.lookup(new_group, :watching_first_post).pluck(:tag_id),
      ).to contain_exactly(tag1.id, tag3.id)
    end

    it "can take tag synonyms" do
      group.tracking_tags = [synonym1.name, synonym2.name, tag3.name]
      group.save!
      expect(
        GroupTagNotificationDefault.lookup(group, :tracking).pluck(:tag_id),
      ).to contain_exactly(tag1.id, tag2.id, tag3.id)

      group.tracking_tags = [synonym1.name, synonym2.name, tag1.name, tag2.name, tag3.name]
      group.save!
      expect(
        GroupTagNotificationDefault.lookup(group, :tracking).pluck(:tag_id),
      ).to contain_exactly(tag1.id, tag2.id, tag3.id)
    end

    it "can remove tags" do
      [tag1, tag2].each do |tag|
        GroupTagNotificationDefault.create!(
          group: group,
          tag: tag,
          notification_level: GroupTagNotificationDefault.notification_levels[:watching],
        )
      end

      group.watching_tags = [tag2.name]
      group.save!
      expect(GroupTagNotificationDefault.lookup(group, :watching).pluck(:tag_id)).to eq([tag2.id])

      group.watching_tags = []
      group.save!
      expect(GroupTagNotificationDefault.lookup(group, :watching)).to be_empty
    end

    it "can change the notification level for a tag" do
      GroupTagNotificationDefault.create!(
        group: group,
        tag: tag1,
        notification_level: GroupTagNotificationDefault.notification_levels[:watching],
      )

      group.watching_tags = [tag1.name]
      group.save!
      expect(GroupTagNotificationDefault.lookup(group, :watching).pluck(:tag_id)).to eq([tag1.id])

      group.watching_tags = []
      group.tracking_tags = [tag1.name]
      group.save!
      expect(GroupTagNotificationDefault.lookup(group, :watching)).to be_empty
      expect(GroupTagNotificationDefault.lookup(group, :tracking).pluck(:tag_id)).to eq([tag1.id])
    end

    it "can apply default notifications for admins group" do
      group = Group.find(Group::AUTO_GROUPS[:admins])
      group.tracking_category_ids = [category1.id]
      group.tracking_tags = [tag1.name]
      group.save!
      user.grant_admin!
      expect(CategoryUser.lookup(user, :tracking).pluck(:category_id)).to eq([category1.id])
      expect(TagUser.lookup(user, :tracking).pluck(:tag_id)).to eq([tag1.id])
    end

    it "can apply default notifications for staff group" do
      group = Group.find(Group::AUTO_GROUPS[:staff])
      group.tracking_category_ids = [category1.id]
      group.tracking_tags = [tag1.name]
      group.save!
      user.grant_admin!
      expect(CategoryUser.lookup(user, :tracking).pluck(:category_id)).to eq([category1.id])
      expect(TagUser.lookup(user, :tracking).pluck(:tag_id)).to eq([tag1.id])
    end

    it "can apply default notifications from two automatic groups" do
      staff = Group.find(Group::AUTO_GROUPS[:staff])
      staff.tracking_category_ids = [category1.id]
      staff.tracking_tags = [tag1.name]
      staff.save!
      admins = Group.find(Group::AUTO_GROUPS[:admins])
      admins.tracking_category_ids = [category2.id]
      admins.tracking_tags = [tag2.name]
      admins.save!
      user.grant_admin!
      expect(CategoryUser.lookup(user, :tracking).pluck(:category_id)).to contain_exactly(
        category1.id,
        category2.id,
      )
      expect(TagUser.lookup(user, :tracking).pluck(:tag_id)).to contain_exactly(tag1.id, tag2.id)
    end
  end

  describe "email setting changes" do
    it "enables smtp and records the change" do
      group.update(
        smtp_port: 587,
        smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
        smtp_server: "smtp.gmail.com",
        email_username: "test@gmail.com",
        email_password: "password",
      )

      group.record_email_setting_changes!(user)
      group.reload

      expect(group.smtp_enabled).to eq(true)
      expect(group.smtp_updated_at).not_to eq(nil)
      expect(group.smtp_updated_by).to eq(user)
    end

    it "records the change for singular setting changes" do
      group.update(
        smtp_port: 587,
        smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
        smtp_server: "smtp.gmail.com",
        email_username: "test@gmail.com",
        email_password: "password",
      )
      group.record_email_setting_changes!(user)
      group.reload

      old_updated_at = group.smtp_updated_at
      group.update(email_from_alias: "somealias@gmail.com")
      group.record_email_setting_changes!(user)
      expect(group.reload.smtp_updated_at).not_to eq_time(old_updated_at)
    end

    it "enables imap and records the change" do
      group.update(
        imap_port: 587,
        imap_ssl: true,
        imap_server: "imap.gmail.com",
        email_username: "test@gmail.com",
        email_password: "password",
      )

      group.record_email_setting_changes!(user)
      group.reload

      expect(group.imap_enabled).to eq(true)
      expect(group.imap_updated_at).not_to eq(nil)
      expect(group.imap_updated_by).to eq(user)
    end

    it "disables smtp and records the change" do
      group.update(
        smtp_port: 587,
        smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
        smtp_server: "smtp.gmail.com",
        email_username: "test@gmail.com",
        email_password: "password",
        smtp_updated_by: user,
      )

      group.record_email_setting_changes!(user)
      group.reload

      group.update(
        smtp_port: nil,
        smtp_ssl_mode: Group.smtp_ssl_modes[:none],
        smtp_server: nil,
        email_username: nil,
        email_password: nil,
      )

      group.record_email_setting_changes!(user)
      group.reload

      expect(group.smtp_enabled).to eq(false)
      expect(group.smtp_updated_at).not_to eq(nil)
      expect(group.smtp_updated_by).to eq(user)
    end

    it "disables imap and records the change" do
      group.update(
        imap_port: 587,
        imap_ssl: true,
        imap_server: "imap.gmail.com",
        email_username: "test@gmail.com",
        email_password: "password",
      )

      group.record_email_setting_changes!(user)
      group.reload

      group.update(
        imap_port: nil,
        imap_ssl: false,
        imap_server: nil,
        email_username: nil,
        email_password: nil,
      )

      group.record_email_setting_changes!(user)
      group.reload

      expect(group.imap_enabled).to eq(false)
      expect(group.imap_updated_at).not_to eq(nil)
      expect(group.imap_updated_by).to eq(user)
    end
  end

  describe "#find_by_email" do
    it "finds the group by any of its incoming emails" do
      group.update!(incoming_email: "abc@test.com|support@test.com")
      expect(Group.find_by_email("abc@test.com")).to eq(group)
      expect(Group.find_by_email("support@test.com")).to eq(group)
      expect(Group.find_by_email("nope@test.com")).to eq(nil)
    end

    it "finds the group by its email_username" do
      group.update!(email_username: "abc@test.com", incoming_email: "support@test.com")
      expect(Group.find_by_email("abc@test.com")).to eq(group)
      expect(Group.find_by_email("support@test.com")).to eq(group)
      expect(Group.find_by_email("nope@test.com")).to eq(nil)
    end

    it "finds the group by its email_from_alias" do
      group.update!(email_username: "abc@test.com", email_from_alias: "somealias@test.com")
      expect(Group.find_by_email("abc@test.com")).to eq(group)
      expect(Group.find_by_email("somealias@test.com")).to eq(group)
      expect(Group.find_by_email("nope@test.com")).to eq(nil)
    end
  end
end
