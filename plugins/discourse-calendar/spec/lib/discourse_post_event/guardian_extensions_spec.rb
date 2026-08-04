# frozen_string_literal: true

RSpec.describe DiscoursePostEvent::GuardianExtensions do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user, :user)
  fab!(:allowed_group) do
    Fabricate(:group).tap do |group|
      group.add(user)
      group.save!
    end
  end
  fab!(:own_post) { Fabricate(:post, user:, topic: Fabricate(:topic, user:)) }
  fab!(:own_event) { Fabricate(:event, post: own_post) }
  fab!(:other_post) do
    Fabricate(:post, user: other_user, topic: Fabricate(:topic, user: other_user))
  end
  fab!(:other_event) { Fabricate(:event, post: other_post) }

  let(:guardian) { user.guardian }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = allowed_group.id
  end

  describe "#can_create_discourse_post_event?" do
    it "allows staff, members of an allowed group, and everyone when configured" do
      expect(Fabricate(:admin).guardian.can_create_discourse_post_event?).to eq(true)
      expect(guardian.can_create_discourse_post_event?).to eq(true)

      # TODO: Remove this when everyone pseudogroup is no longer valid after
      # granular_anonymous_and_logged_in_groups_permissions is permanent
      SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:everyone]
      expect(other_user.guardian.can_create_discourse_post_event?).to eq(true)
    end

    it "denies anonymous users and users outside the allowed groups" do
      expect(Guardian.new.can_create_discourse_post_event?).to be_falsey
      expect(other_user.guardian.can_create_discourse_post_event?).to eq(false)
    end

    it "allows logged_in_users when configured" do
      SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:logged_in_users]
      expect(other_user.guardian.can_create_discourse_post_event?).to eq(true)
    end
  end

  describe "#can_act_on_discourse_post_event?" do
    it "allows staff and an allowed event author" do
      expect(Fabricate(:admin).guardian.can_act_on_discourse_post_event?(other_event)).to eq(true)
      expect(guardian.can_act_on_discourse_post_event?(own_event)).to eq(true)
    end

    it "allows an allowed user who can edit someone else's post" do
      user.update!(trust_level: TrustLevel[4])
      Group.refresh_automatic_groups!

      expect(guardian.can_act_on_discourse_post_event?(other_event)).to eq(true)
    end

    it "denies an allowed user who cannot edit the event post" do
      expect(guardian.can_act_on_discourse_post_event?(other_event)).to eq(false)
    end

    it "denies an event author outside the allowed groups" do
      expect(other_user.guardian.can_act_on_discourse_post_event?(other_event)).to eq(false)
    end

    it "does not reuse the result from another event" do
      expect(guardian.can_act_on_discourse_post_event?(own_event)).to eq(true)
      expect(guardian.can_act_on_discourse_post_event?(other_event)).to eq(false)
      expect(guardian.can_act_on_discourse_post_event?(own_event)).to eq(true)
    end
  end

  describe "#can_act_on_invitee?" do
    it "allows an invitee to act on their own attendance" do
      invitee =
        Fabricate(
          :invitee,
          event: other_event,
          user:,
          status: DiscoursePostEvent::Invitee.statuses[:going],
        )

      expect(guardian.can_act_on_invitee?(invitee)).to eq(true)
    end

    it "allows an event manager and denies an unrelated user" do
      invitee =
        Fabricate(
          :invitee,
          event: own_event,
          user: other_user,
          status: DiscoursePostEvent::Invitee.statuses[:going],
        )

      expect(guardian.can_act_on_invitee?(invitee)).to eq(true)
      expect(Fabricate(:user).guardian.can_act_on_invitee?(invitee)).to eq(false)
    end
  end

  describe "#can_display_invitee_details?" do
    it "allows anyone to see invitee details for a public event" do
      expect(Guardian.new.can_display_invitee_details?(other_event)).to eq(true)
    end

    it "allows an event manager to see invitee details for a private event" do
      own_event.update!(status: DiscoursePostEvent::Event.statuses[:private])

      expect(guardian.can_display_invitee_details?(own_event)).to eq(true)
    end

    it "allows an invited group member even when the group's details are hidden" do
      hidden_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:owners],
          members_visibility_level: Group.visibility_levels[:owners],
        )
      hidden_group.add(user)
      other_event.update!(
        status: DiscoursePostEvent::Event.statuses[:private],
        raw_invitees: [hidden_group.name],
      )

      expect(guardian.can_display_invitee_details?(other_event)).to eq(true)
    end

    it "allows a user who can see every invited group and its members" do
      visible_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:public],
          members_visibility_level: Group.visibility_levels[:public],
        )
      other_event.update!(
        status: DiscoursePostEvent::Event.statuses[:private],
        raw_invitees: [visible_group.name],
      )

      expect(guardian.can_display_invitee_details?(other_event)).to eq(true)
    end

    it "denies a user when an invited group or its members are hidden" do
      hidden_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:owners],
          members_visibility_level: Group.visibility_levels[:owners],
        )
      other_event.update!(
        status: DiscoursePostEvent::Event.statuses[:private],
        raw_invitees: [hidden_group.name],
      )

      expect(guardian.can_display_invitee_details?(other_event)).to eq(false)
    end

    it "denies a user when a private event has no invited groups" do
      other_event.update!(status: DiscoursePostEvent::Event.statuses[:private], raw_invitees: [])

      expect(guardian.can_display_invitee_details?(other_event)).to eq(false)
    end
  end

  describe "#can_export_entity?" do
    it "allows an event manager to export the event" do
      expect(guardian.can_export_entity?("post_event", nil, id: own_event.id)).to eq(true)
    end

    it "denies the export when events are disabled or the event does not exist" do
      SiteSetting.discourse_post_event_enabled = false
      expect(guardian.can_export_entity?("post_event", nil, id: own_event.id)).to eq(false)

      SiteSetting.discourse_post_event_enabled = true
      expect(guardian.can_export_entity?("post_event", nil, id: -1)).to eq(false)
    end

    it "preserves core export permissions for other entity types" do
      expect(Fabricate(:admin).guardian.can_export_entity?("user_list")).to eq(true)
    end
  end
end
