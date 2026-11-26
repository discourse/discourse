# frozen_string_literal: true

RSpec.describe UserBadge do
  fab!(:badge)
  fab!(:user)

  describe "Validations" do
    let(:subject) { BadgeGranter.grant(badge, user) }

    it { is_expected.to validate_presence_of(:badge_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:granted_at) }
    it { is_expected.to validate_presence_of(:granted_by) }
    it { is_expected.to validate_uniqueness_of(:badge_id).scoped_to(:user_id) }
  end

  describe "#save" do
    it "triggers the 'user_badge_granted' DiscourseEvent" do
      user_badge =
        UserBadge.new(
          badge: badge,
          user: user,
          granted_at: Time.zone.now,
          granted_by: Discourse.system_user,
        )

      event =
        DiscourseEvent.track(:user_badge_granted, args: [badge.id, user.id]) { user_badge.save! }

      expect(event).to be_present
    end
  end

  describe "#destroy" do
    it "triggers the 'user_badge_revoked' DiscourseEvent" do
      user_badge =
        UserBadge.create(
          badge: badge,
          user: user,
          granted_at: Time.zone.now,
          granted_by: Discourse.system_user,
        )

      event = DiscourseEvent.track(:user_badge_revoked) { user_badge.destroy! }

      expect(event).to be_present
    end
  end

  describe ".with_visible_profiles" do
    fab!(:trusted_grantee) { Fabricate(:user, trust_level: TrustLevel[2]) }
    fab!(:tl1_posted_grantee, :trust_level_1)
    fab!(:tl1_grantee, :trust_level_1)
    fab!(:tl0_posted_grantee, :trust_level_0)
    fab!(:tl0_grantee, :trust_level_0)
    fab!(:hidden_grantee) { Fabricate(:user, trust_level: TrustLevel[2]) }
    fab!(:hidden_admin_grantee, :admin)
    fab!(:admin_grantee, :admin)
    fab!(:moderator_grantee, :moderator)
    fab!(:staged_grantee, :staged)
    fab!(:statless_grantee, :trust_level_1)
    fab!(:self_grantee, :trust_level_1)

    let(:grantees) do
      [
        trusted_grantee,
        tl1_posted_grantee,
        tl1_grantee,
        tl0_posted_grantee,
        tl0_grantee,
        hidden_grantee,
        hidden_admin_grantee,
        admin_grantee,
        moderator_grantee,
        staged_grantee,
        statless_grantee,
        self_grantee,
      ]
    end

    before do
      tl1_posted_grantee.user_stat.update!(post_count: 1)
      tl0_posted_grantee.user_stat.update!(post_count: 1)
      hidden_grantee.user_option.update!(hide_profile: true)
      hidden_admin_grantee.user_option.update!(hide_profile: true)
      self_grantee.user_option.update!(hide_profile: true)
      statless_grantee.user_stat&.destroy!
      statless_grantee.reload

      grantees.each { |grantee| Fabricate(:user_badge, badge:, user: grantee) }
    end

    it "matches Guardian#can_see_profile? for every viewer and profile setting" do
      viewers = {
        "anonymous" => nil,
        "trust level 0" => Fabricate(:trust_level_0),
        "trust level 1" => tl1_grantee,
        "trust level 1 with a post" => tl1_posted_grantee,
        "trust level 2" => trusted_grantee,
        "hidden profile owner" => self_grantee,
        "moderator" => Fabricate(:moderator),
        "admin" => Fabricate(:admin),
      }

      [
        { hide_new_user_profiles: true, allow_users_to_hide_profile: true },
        { hide_new_user_profiles: true, allow_users_to_hide_profile: false },
        { hide_new_user_profiles: false, allow_users_to_hide_profile: true },
        { hide_new_user_profiles: false, allow_users_to_hide_profile: false },
        { hide_new_user_profiles: true, invite_only: true },
        { hide_new_user_profiles: true, must_approve_users: true },
        { hide_new_user_profiles: true, hide_user_profiles_from_public: true },
      ].each do |settings|
        {
          hide_new_user_profiles: false,
          allow_users_to_hide_profile: false,
          invite_only: false,
          must_approve_users: false,
          hide_user_profiles_from_public: false,
        }.merge(settings).each { |name, value| SiteSetting.public_send(:"#{name}=", value) }

        viewers.each do |viewer_name, viewer|
          guardian = Guardian.new(viewer)
          visible_ids = grantees.select { |grantee| guardian.can_see_profile?(grantee) }.map(&:id)

          expect(UserBadge.with_visible_profiles(guardian).pluck(:user_id).uniq).to contain_exactly(
            *visible_ids,
          ),
          "#{viewer_name} viewer with #{settings}"
        end
      end
    end

    it "hides every profile from anonymous visitors when public profiles are hidden" do
      SiteSetting.hide_user_profiles_from_public = true

      expect(Guardian.new.can_see_profile?(trusted_grantee)).to eq(false)
      expect(UserBadge.with_visible_profiles(Guardian.new)).to be_empty
    end

    it "still shows profiles to logged-in visitors when public profiles are hidden" do
      SiteSetting.hide_user_profiles_from_public = true
      guardian = Guardian.new(tl1_posted_grantee)

      expect(UserBadge.with_visible_profiles(guardian).pluck(:user_id)).to include(
        trusted_grantee.id,
        tl1_posted_grantee.id,
      )
    end
  end

  describe "featured rank" do
    fab!(:user)
    fab!(:user_2, :user)
    fab!(:user_badge_tl1) do
      UserBadge.create!(
        badge_id: Badge::BasicUser,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end
    fab!(:user_badge_tl2) do
      UserBadge.create!(
        badge_id: Badge::Member,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end
    fab!(:user_badge_wiki) do
      UserBadge.create!(
        badge_id: Badge::WikiEditor,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end
    fab!(:user_badge_like) do
      UserBadge.create!(
        badge_id: Badge::FirstLike,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end

    fab!(:user_2_badge_tl1) do
      UserBadge.create!(
        badge_id: Badge::BasicUser,
        user: user_2,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end

    it "gives user badges the correct rank" do
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_badge_wiki.reload.featured_rank).to eq(2)
      expect(user_badge_like.reload.featured_rank).to eq(3)
      expect(user_badge_tl1.reload.featured_rank).to eq(4) # Previous trust level badges last
    end

    it "gives duplicate user_badges the same rank" do
      ub1 =
        UserBadge.create!(
          badge_id: Badge::GreatTopic,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
        )
      ub2 =
        UserBadge.create!(
          badge_id: Badge::GreatTopic,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
          seq: 1,
        )

      expect(ub1.reload.featured_rank).to eq(2)
      expect(ub2.reload.featured_rank).to eq(2)
    end

    it "skips disabled badges" do
      user_badge_wiki.badge.update(enabled: false)
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_badge_like.reload.featured_rank).to eq(2)
      expect(user_badge_tl1.reload.featured_rank).to eq(3) # Previous trust level badges last
      expect(user_badge_wiki.reload.featured_rank).to eq(4) # Disabled
    end

    it "can ensure consistency per user" do
      user_badge_tl2.update_column(:featured_rank, 20) # Update without hooks
      expect(user_badge_tl2.reload.featured_rank).to eq(20) # Double check
      user_2_badge_tl1.update_column(:featured_rank, 20) # Update without hooks
      expect(user_2_badge_tl1.reload.featured_rank).to eq(20) # Double check

      UserBadge.update_featured_ranks!([user.id])

      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_2_badge_tl1.reload.featured_rank).to eq(20)
    end

    it "can ensure consistency for all users" do
      user_badge_tl2.update_column(:featured_rank, 20) # Update without hooks
      expect(user_badge_tl2.reload.featured_rank).to eq(20) # Double check
      user_2_badge_tl1.update_column(:featured_rank, 20) # Update without hooks
      expect(user_2_badge_tl1.reload.featured_rank).to eq(20) # Double check

      UserBadge.update_featured_ranks!

      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_2_badge_tl1.reload.featured_rank).to eq(1)
    end
  end
end
