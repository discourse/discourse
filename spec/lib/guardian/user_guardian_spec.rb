# frozen_string_literal: true

RSpec.describe UserGuardian do
  let :user do
    Fabricate(:user)
  end

  let :moderator do
    Fabricate(:moderator)
  end

  let :admin do
    Fabricate(:admin)
  end

  let(:user_avatar) { Fabricate(:user_avatar, user: user) }

  let :users_upload do
    Upload.new(user_id: user_avatar.user_id, id: 1)
  end

  let :already_uploaded do
    u = Upload.new(user_id: 9999, id: 2)
    user_avatar.custom_upload_id = u.id
    u
  end

  let :not_my_upload do
    Upload.new(user_id: 9999, id: 3)
  end

  let(:moderator_upload) { Upload.new(user_id: moderator.id, id: 4) }

  fab!(:trust_level_1)
  fab!(:trust_level_2)

  describe "#can_pick_avatar?" do
    let :guardian do
      Guardian.new(user)
    end

    context "with anon user" do
      let(:guardian) { Guardian.new }

      it "should return the right value" do
        expect(guardian.can_pick_avatar?(user_avatar, users_upload)).to eq(false)
      end
    end

    context "with current user" do
      it "can not set uploads not owned by current user" do
        expect(guardian.can_pick_avatar?(user_avatar, users_upload)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, already_uploaded)).to eq(true)

        UserUpload.create!(upload_id: not_my_upload.id, user_id: not_my_upload.user_id)

        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(false)
        expect(guardian.can_pick_avatar?(user_avatar, nil)).to eq(true)
      end

      it "can handle uploads that are associated but not directly owned" do
        UserUpload.create!(upload_id: not_my_upload.id, user_id: user_avatar.user_id)

        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(true)
      end
    end

    context "with moderator" do
      let :guardian do
        Guardian.new(moderator)
      end

      it "is secure" do
        expect(guardian.can_pick_avatar?(user_avatar, moderator_upload)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, users_upload)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, already_uploaded)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(false)
        expect(guardian.can_pick_avatar?(user_avatar, nil)).to eq(true)
      end
    end

    context "with admin" do
      let :guardian do
        Guardian.new(admin)
      end

      it "is secure" do
        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, nil)).to eq(true)
      end
    end
  end

  describe "#can_see_user?" do
    it "is always true" do
      expect(Guardian.new.can_see_user?(anything)).to eq(true)
    end
  end

  describe "#can_see_profile?" do
    fab!(:tl0_user) { Fabricate(:user, trust_level: 0) }
    fab!(:tl1_user) { Fabricate(:user, trust_level: 1) }
    fab!(:tl2_user) { Fabricate(:user, trust_level: 2) }

    before { tl2_user.user_stat.update!(post_count: 1) }

    context "when viewing the profile of a user with 0 posts" do
      before { user.user_stat.update!(post_count: 0) }

      it "they can view their own profile" do
        expect(Guardian.new(user).can_see_profile?(user)).to eq(true)
      end

      it "an anonymous user cannot view the user's profile" do
        expect(Guardian.new.can_see_profile?(user)).to eq(false)
      end

      it "a TL0 user cannot view the user's profile" do
        expect(Guardian.new(tl0_user).can_see_profile?(user)).to eq(false)
      end

      it "a TL1 user cannot view the user's profile" do
        expect(Guardian.new(tl1_user).can_see_profile?(user)).to eq(false)
      end

      it "an anonymous user can view the user's profile if allow_low_trust_levels_to_view_user_profiles is true" do
        SiteSetting.allow_low_trust_levels_to_view_user_profiles = true
        expect(Guardian.new.can_see_profile?(user)).to eq(true)
      end

      it "a TL0 user can view the user's profile if allow_low_trust_levels_to_view_user_profiles is true" do
        SiteSetting.allow_low_trust_levels_to_view_user_profiles = true
        expect(Guardian.new(tl0_user).can_see_profile?(user)).to eq(true)
      end

      it "a TL1 user can view the user's profile if allow_low_trust_levels_to_view_user_profiles is true" do
        SiteSetting.allow_low_trust_levels_to_view_user_profiles = true
        expect(Guardian.new(tl1_user).can_see_profile?(user)).to eq(true)
      end

      it "a TL2 user can view the user's profile" do
        expect(Guardian.new(tl2_user).can_see_profile?(user)).to eq(true)
      end

      it "a moderator can view the user's profile" do
        expect(Guardian.new(moderator).can_see_profile?(user)).to eq(true)
      end

      it "an admin can view the user's profile" do
        expect(Guardian.new(admin).can_see_profile?(user)).to eq(true)
      end

      context "when the profile is hidden" do
        before do
          SiteSetting.allow_users_to_hide_profile = true
          user.user_option.update!(hide_profile: true)
        end

        it "they can view their own profile" do
          expect(Guardian.new(user).can_see_profile?(user)).to eq(true)
        end

        it "a TL2 user cannot view the user's profile" do
          expect(Guardian.new(tl2_user).can_see_profile?(user)).to eq(false)
        end

        it "a moderator can view the user's profile" do
          expect(Guardian.new(moderator).can_see_profile?(user)).to eq(true)
        end

        it "an admin can view the user's profile" do
          expect(Guardian.new(admin).can_see_profile?(user)).to eq(true)
        end
      end
    end

    context "when viewing the profile of a TL0 user with more than 0 posts" do
      before { tl0_user.user_stat.update!(post_count: 1) }

      it "they can view their own profile" do
        expect(Guardian.new(tl0_user).can_see_profile?(tl0_user)).to eq(true)
      end

      it "an anonymous user cannot view the user's profile" do
        expect(Guardian.new.can_see_profile?(tl0_user)).to eq(false)
      end

      it "a TL0 user cannot view the user's profile" do
        expect(Guardian.new(Fabricate(:user, trust_level: 0)).can_see_profile?(tl0_user)).to eq(
          false,
        )
      end

      it "an anonymous user can view the user's profile if allow_low_trust_levels_to_view_user_profiles is true" do
        SiteSetting.allow_low_trust_levels_to_view_user_profiles = true
        expect(Guardian.new.can_see_profile?(tl0_user)).to eq(true)
      end

      it "a TL0 user can view the user's profile if allow_low_trust_levels_to_view_user_profiles is true" do
        SiteSetting.allow_low_trust_levels_to_view_user_profiles = true
        expect(Guardian.new(Fabricate(:user, trust_level: 0)).can_see_profile?(tl0_user)).to eq(
          true,
        )
      end

      it "a TL1 user can view the user's profile" do
        expect(Guardian.new(tl1_user).can_see_profile?(tl0_user)).to eq(true)
      end

      it "a TL2 user can view the user's profile" do
        expect(Guardian.new(tl2_user).can_see_profile?(tl0_user)).to eq(true)
      end

      it "a moderator user can view the user's profile" do
        expect(Guardian.new(moderator).can_see_profile?(tl0_user)).to eq(true)
      end

      it "an admin user can view the user's profile" do
        expect(Guardian.new(admin).can_see_profile?(tl0_user)).to eq(true)
      end

      context "when the profile is hidden" do
        before do
          SiteSetting.allow_users_to_hide_profile = true
          tl0_user.user_option.update!(hide_profile: true)
        end

        it "they can view their own profile" do
          expect(Guardian.new(tl0_user).can_see_profile?(tl0_user)).to eq(true)
        end

        it "a TL1 user cannot view the user's profile" do
          expect(Guardian.new(tl1_user).can_see_profile?(tl0_user)).to eq(false)
        end

        it "a TL2 user cannot view the user's profile" do
          expect(Guardian.new(tl2_user).can_see_profile?(tl0_user)).to eq(false)
        end

        it "a moderator user can view the user's profile" do
          expect(Guardian.new(moderator).can_see_profile?(tl0_user)).to eq(true)
        end

        it "an admin user can view the user's profile" do
          expect(Guardian.new(admin).can_see_profile?(tl0_user)).to eq(true)
        end
      end
    end

    context "when the allow_users_to_hide_profile setting is false" do
      before { SiteSetting.allow_users_to_hide_profile = false }

      it "doesn't hide the profile even if the hide_profile user option is true" do
        tl2_user.user_option.update!(hide_profile: true)

        expect(Guardian.new(tl0_user).can_see_profile?(tl2_user)).to eq(true)
        expect(Guardian.new(tl1_user).can_see_profile?(tl2_user)).to eq(true)
        expect(Guardian.new(admin).can_see_profile?(tl2_user)).to eq(true)
        expect(Guardian.new(moderator).can_see_profile?(tl2_user)).to eq(true)
      end
    end

    context "when the allow_users_to_hide_profile setting is true" do
      before { SiteSetting.allow_users_to_hide_profile = true }

      it "doesn't allow non-staff users to view the user's profile if the hide_profile user option is true" do
        tl2_user.user_option.update!(hide_profile: true)

        expect(Guardian.new(tl0_user).can_see_profile?(tl2_user)).to eq(false)
        expect(Guardian.new(tl1_user).can_see_profile?(tl2_user)).to eq(false)

        expect(Guardian.new(admin).can_see_profile?(tl2_user)).to eq(true)
        expect(Guardian.new(moderator).can_see_profile?(tl2_user)).to eq(true)
      end

      it "allows everyone to view the user's profile if the hide_profile user option is false" do
        tl2_user.user_option.update!(hide_profile: false)

        expect(Guardian.new(tl0_user).can_see_profile?(tl2_user)).to eq(true)
        expect(Guardian.new(tl1_user).can_see_profile?(tl2_user)).to eq(true)

        expect(Guardian.new(admin).can_see_profile?(tl2_user)).to eq(true)
        expect(Guardian.new(moderator).can_see_profile?(tl2_user)).to eq(true)
      end
    end

    it "is false for no user" do
      expect(Guardian.new.can_see_profile?(nil)).to eq(false)
    end

    it "is true for staff users even when they have no posts" do
      admin.user_stat.update!(post_count: 0)
      moderator.user_stat.update!(post_count: 0)

      expect(Guardian.new.can_see_profile?(admin)).to eq(true)
      expect(Guardian.new.can_see_profile?(moderator)).to eq(true)
    end
  end

  describe "#can_see_user_actions?" do
    it "is true by default" do
      expect(Guardian.new.can_see_user_actions?(nil, [])).to eq(true)
    end

    context "with 'hide_user_activity_tab' setting" do
      before { SiteSetting.hide_user_activity_tab = false }

      it "returns true for self" do
        expect(Guardian.new(user).can_see_user_actions?(user, [])).to eq(true)
      end

      it "returns true for admin" do
        expect(Guardian.new(admin).can_see_user_actions?(user, [])).to eq(true)
      end

      it "returns false for regular user" do
        expect(Guardian.new.can_see_user_actions?(user, [])).to eq(true)
      end
    end
  end

  describe "#allowed_user_field_ids" do
    let! :fields do
      [
        Fabricate(:user_field),
        Fabricate(:user_field),
        Fabricate(:user_field, show_on_profile: true),
        Fabricate(:user_field, show_on_user_card: true),
        Fabricate(:user_field, show_on_user_card: true, show_on_profile: true),
      ]
    end

    let :user2 do
      Fabricate(:user)
    end

    it "returns all fields for staff" do
      guardian = Guardian.new(admin)
      expect(guardian.allowed_user_field_ids(user)).to contain_exactly(*fields.map(&:id))
    end

    it "returns all fields for self" do
      guardian = Guardian.new(user)
      expect(guardian.allowed_user_field_ids(user)).to contain_exactly(*fields.map(&:id))
    end

    it "returns only public fields for others" do
      guardian = Guardian.new(user)
      expect(guardian.allowed_user_field_ids(user2)).to contain_exactly(*fields[2..5].map(&:id))
    end

    it "has a different cache per user" do
      guardian = Guardian.new(user)
      expect(guardian.allowed_user_field_ids(user2)).to contain_exactly(*fields[2..5].map(&:id))
      expect(guardian.allowed_user_field_ids(user)).to contain_exactly(*fields.map(&:id))
    end
  end

  describe "#can_delete_user?" do
    shared_examples "can_delete_user examples" do
      it "isn't allowed if user is an admin" do
        another_admin = Fabricate(:admin)
        expect(guardian.can_delete_user?(another_admin)).to eq(false)
      end
    end

    shared_examples "can_delete_user staff examples" do
      it "is allowed when user didn't create a post yet" do
        expect(user.first_post_created_at).to be_nil
        expect(guardian.can_delete_user?(user)).to eq(true)
      end

      context "when user created too many posts" do
        before { (User::MAX_STAFF_DELETE_POST_COUNT + 1).times { Fabricate(:post, user: user) } }

        it "is allowed when user created the first post within delete_user_max_post_age days" do
          SiteSetting.delete_user_max_post_age = 2

          user.user_stat = UserStat.new(new_since: 3.days.ago, first_post_created_at: 1.day.ago)
          expect(guardian.can_delete_user?(user)).to eq(true)

          user.user_stat = UserStat.new(new_since: 3.days.ago, first_post_created_at: 3.day.ago)
          expect(guardian.can_delete_user?(user)).to eq(false)
        end
      end

      context "when user didn't create many posts" do
        before { (User::MAX_STAFF_DELETE_POST_COUNT - 1).times { Fabricate(:post, user: user) } }

        it "is allowed when even when user created the first post before delete_user_max_post_age days" do
          SiteSetting.delete_user_max_post_age = 2

          user.user_stat = UserStat.new(new_since: 3.days.ago, first_post_created_at: 3.day.ago)
          expect(guardian.can_delete_user?(user)).to eq(true)
        end
      end
    end

    context "when deleting myself" do
      let(:guardian) { Guardian.new(user) }

      include_examples "can_delete_user examples"

      it "isn't allowed when SSO is enabled" do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "isn't allowed when user created too many posts" do
        topic = Fabricate(:topic)
        Fabricate(:post, topic: topic, user: user)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, topic: topic, user: user)
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "isn't allowed when user created too many posts in PM" do
        topic = Fabricate(:private_message_topic, user: user)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "is allowed when user responded to PM from system user" do
        topic =
          Fabricate(
            :private_message_topic,
            user: Discourse.system_user,
            topic_allowed_users: [
              Fabricate.build(:topic_allowed_user, user: Discourse.system_user),
              Fabricate.build(:topic_allowed_user, user: user),
            ],
          )

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)
      end

      it "is allowed when user created multiple posts in PMs to themselves" do
        topic =
          Fabricate(
            :private_message_topic,
            user: user,
            topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
          )

        Fabricate(:post, user: user, topic: topic)
        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)
      end

      it "isn't allowed when user created multiple posts in PMs sent to other users" do
        topic =
          Fabricate(
            :private_message_topic,
            user: user,
            topic_allowed_users: [
              Fabricate.build(:topic_allowed_user, user: user),
              Fabricate.build(:topic_allowed_user, user: Fabricate(:user)),
            ],
          )

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "isn't allowed when user created multiple posts in PMs sent to groups" do
        topic =
          Fabricate(
            :private_message_topic,
            user: user,
            topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
            topic_allowed_groups: [
              Fabricate.build(:topic_allowed_group, group: Fabricate(:group)),
              Fabricate.build(:topic_allowed_group, group: Fabricate(:group)),
            ],
          )

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "isn't allowed when site admin blocked self deletion" do
        expect(user.first_post_created_at).to be_nil

        SiteSetting.delete_user_self_max_post_count = -1
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "correctly respects the delete_user_self_max_post_count setting" do
        topic = Fabricate(:topic)

        SiteSetting.delete_user_self_max_post_count = 0
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, topic: topic, user: user)

        expect(guardian.can_delete_user?(user)).to eq(false)
        SiteSetting.delete_user_self_max_post_count = 1
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, topic: topic, user: user)

        expect(guardian.can_delete_user?(user)).to eq(false)
        SiteSetting.delete_user_self_max_post_count = 2
        expect(guardian.can_delete_user?(user)).to eq(true)
      end
    end

    context "for moderators" do
      let(:guardian) { Guardian.new(moderator) }
      include_examples "can_delete_user examples"
      include_examples "can_delete_user staff examples"
    end

    context "for admins" do
      let(:guardian) { Guardian.new(admin) }
      include_examples "can_delete_user examples"
      include_examples "can_delete_user staff examples"
    end
  end

  describe "#can_merge_user?" do
    shared_examples "can_merge_user examples" do
      it "isn't allowed if user is a staff" do
        staff = Fabricate(:moderator)
        expect(guardian.can_merge_user?(staff)).to eq(false)
      end
    end

    context "for moderators" do
      let(:guardian) { Guardian.new(moderator) }
      include_examples "can_merge_user examples"

      it "isn't allowed if current_user is not an admin" do
        expect(guardian.can_merge_user?(user)).to eq(false)
      end
    end

    context "for admins" do
      let(:guardian) { Guardian.new(admin) }
      include_examples "can_merge_user examples"
    end
  end

  describe "#can_see_review_queue?" do
    it "returns true when the user is a staff member" do
      guardian = Guardian.new(moderator)
      expect(guardian.can_see_review_queue?).to eq(true)
    end

    it "returns false for a regular user" do
      guardian = Guardian.new(user)
      expect(guardian.can_see_review_queue?).to eq(false)
    end

    it "returns true when the user's group can review an item in the queue" do
      group = Fabricate(:group)
      group.add(user)
      guardian = Guardian.new(user)
      SiteSetting.enable_category_group_moderation = true
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)

      Fabricate(:reviewable_flagged_post, category:)

      expect(guardian.can_see_review_queue?).to eq(true)
    end

    it "returns false if category group review is disabled" do
      group = Fabricate(:group)
      group.add(user)
      guardian = Guardian.new(user)
      SiteSetting.enable_category_group_moderation = false
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)

      Fabricate(:reviewable_flagged_post, category:)

      expect(guardian.can_see_review_queue?).to eq(false)
    end

    it "returns false if the reviewable is under a read restricted category" do
      group = Fabricate(:group)
      group.add(user)
      guardian = Guardian.new(user)
      SiteSetting.enable_category_group_moderation = true
      category = Fabricate(:category, read_restricted: true)
      Fabricate(:category_moderation_group, category:, group:)

      Fabricate(:reviewable_flagged_post, category: category)

      expect(guardian.can_see_review_queue?).to eq(false)
    end
  end

  describe "can_upload_profile_header" do
    it "returns true if it is an admin" do
      guardian = Guardian.new(admin)
      expect(guardian.can_upload_profile_header?(admin)).to eq(true)
    end

    it "returns true if the group of user matches site setting" do
      guardian = Guardian.new(trust_level_2)
      SiteSetting.profile_background_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      expect(guardian.can_upload_profile_header?(trust_level_2)).to eq(true)
    end

    it "returns false if the group of user does not matches site setting" do
      guardian = Guardian.new(trust_level_1)
      SiteSetting.profile_background_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      expect(guardian.can_upload_profile_header?(trust_level_1)).to eq(false)
    end
  end

  describe "can_upload_user_card_background" do
    it "returns true if it is an admin" do
      guardian = Guardian.new(admin)
      expect(guardian.can_upload_user_card_background?(admin)).to eq(true)
    end

    it "returns true if the trust level of user matches site setting" do
      guardian = Guardian.new(trust_level_2)
      SiteSetting.user_card_background_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      expect(guardian.can_upload_user_card_background?(trust_level_2)).to eq(true)
    end

    it "returns false if the trust level of user does not matches site setting" do
      guardian = Guardian.new(trust_level_1)
      SiteSetting.user_card_background_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      expect(guardian.can_upload_user_card_background?(trust_level_1)).to eq(false)
    end
  end

  describe "#can_change_tracking_preferences?" do
    let(:staged_user) { Fabricate(:staged) }
    let(:admin_user) { Fabricate(:admin) }

    it "is true for normal TL0 user" do
      expect(Guardian.new(user).can_change_tracking_preferences?(user)).to eq(true)
    end

    it "is true for admin user" do
      expect(Guardian.new(admin_user).can_change_tracking_preferences?(admin_user)).to eq(true)
    end

    context "when allow_changing_staged_user_tracking is false" do
      before { SiteSetting.allow_changing_staged_user_tracking = false }

      it "is false to staged user" do
        expect(Guardian.new(staged_user).can_change_tracking_preferences?(staged_user)).to eq(false)
      end

      it "is false for staged user as admin user" do
        expect(Guardian.new(admin_user).can_change_tracking_preferences?(staged_user)).to eq(false)
      end
    end

    context "when allow_changing_staged_user_tracking is true" do
      before { SiteSetting.allow_changing_staged_user_tracking = true }

      it "is true to staged user" do
        expect(Guardian.new(staged_user).can_change_tracking_preferences?(staged_user)).to eq(true)
      end

      it "is true for staged user as admin user" do
        expect(Guardian.new(admin_user).can_change_tracking_preferences?(staged_user)).to eq(true)
      end
    end
  end

  describe "#can_upload_external?" do
    after { Discourse.redis.flushdb }

    it "is true by default" do
      expect(Guardian.new(user).can_upload_external?).to eq(true)
    end

    it "is false if the user has been banned from external uploads for a time period" do
      ExternalUploadManager.ban_user_from_external_uploads!(user: user)
      expect(Guardian.new(user).can_upload_external?).to eq(false)
    end
  end
end
