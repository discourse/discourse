# frozen_string_literal: true

require 'rails_helper'

describe UserGuardian do

  let :user do
    Fabricate(:user)
  end

  let :moderator do
    Fabricate(:moderator)
  end

  let :admin do
    Fabricate(:admin)
  end

  let(:user_avatar) do
    Fabricate(:user_avatar, user: user)
  end

  let :users_upload do
    Upload.new(user_id: user_avatar.user_id, id: 1)
  end

  let :already_uploaded do
    u = Upload.new(user_id: 999, id: 2)
    user_avatar.custom_upload_id = u.id
    u
  end

  let :not_my_upload do
    Upload.new(user_id: 999, id: 3)
  end

  let(:moderator_upload) do
    Upload.new(user_id: moderator.id, id: 4)
  end

  describe '#can_pick_avatar?' do

    let :guardian do
      Guardian.new(user)
    end

    context 'anon user' do
      let(:guardian) { Guardian.new }

      it "should return the right value" do
        expect(guardian.can_pick_avatar?(user_avatar, users_upload)).to eq(false)
      end
    end

    context 'current user' do
      it "can not set uploads not owned by current user" do
        expect(guardian.can_pick_avatar?(user_avatar, users_upload)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, already_uploaded)).to eq(true)

        UserUpload.create!(
          upload_id: not_my_upload.id,
          user_id: not_my_upload.user_id
        )

        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(false)
        expect(guardian.can_pick_avatar?(user_avatar, nil)).to eq(true)
      end

      it "can handle uploads that are associated but not directly owned" do
        UserUpload.create!(
          upload_id: not_my_upload.id,
          user_id: user_avatar.user_id
        )

        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload))
          .to eq(true)
      end
    end

    context 'moderator' do

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

    context 'admin' do
      let :guardian do
        Guardian.new(admin)
      end

      it "is secure" do
        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(true)
        expect(guardian.can_pick_avatar?(user_avatar, nil)).to eq(true)
      end
    end
  end

  describe "#can_see_profile?" do

    it "is false for no user" do
      expect(Guardian.new.can_see_profile?(nil)).to eq(false)
    end

    it "is true for a user whose profile is public" do
      expect(Guardian.new.can_see_profile?(user)).to eq(true)
    end

    context "hidden profile" do
      # Mixing Fabricate.build() and Fabricate() could cause ID clashes, so override :user
      fab!(:user) { Fabricate(:user) }

      let(:hidden_user) do
        result = Fabricate(:user)
        result.user_option.update_column(:hide_profile_and_presence, true)
        result
      end

      it "is false for another user" do
        expect(Guardian.new(user).can_see_profile?(hidden_user)).to eq(false)
      end

      it "is false for an anonymous user" do
        expect(Guardian.new.can_see_profile?(hidden_user)).to eq(false)
      end

      it "is true for the user themselves" do
        expect(Guardian.new(hidden_user).can_see_profile?(hidden_user)).to eq(true)
      end

      it "is true for a staff user" do
        expect(Guardian.new(admin).can_see_profile?(hidden_user)).to eq(true)
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
        Fabricate(:user_field, show_on_user_card: true, show_on_profile: true)
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
        before do
          (User::MAX_STAFF_DELETE_POST_COUNT + 1).times { Fabricate(:post, user: user) }
        end

        it "is allowed when user created the first post within delete_user_max_post_age days" do
          SiteSetting.delete_user_max_post_age = 2

          user.user_stat = UserStat.new(new_since: 3.days.ago, first_post_created_at: 1.day.ago)
          expect(guardian.can_delete_user?(user)).to eq(true)

          user.user_stat = UserStat.new(new_since: 3.days.ago, first_post_created_at: 3.day.ago)
          expect(guardian.can_delete_user?(user)).to eq(false)
        end
      end

      context "when user didn't create many posts" do
        before do
          (User::MAX_STAFF_DELETE_POST_COUNT - 1).times { Fabricate(:post, user: user) }
        end

        it "is allowed when even when user created the first post before delete_user_max_post_age days" do
          SiteSetting.delete_user_max_post_age = 2

          user.user_stat = UserStat.new(new_since: 3.days.ago, first_post_created_at: 3.day.ago)
          expect(guardian.can_delete_user?(user)).to eq(true)
        end
      end
    end

    context "delete myself" do
      let(:guardian) { Guardian.new(user) }

      include_examples "can_delete_user examples"

      it "isn't allowed when SSO is enabled" do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "isn't allowed when user created too many posts" do
        Fabricate(:post, user: user)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user)
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
        topic = Fabricate(:private_message_topic, user: Discourse.system_user, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: Discourse.system_user),
          Fabricate.build(:topic_allowed_user, user: user)
        ])

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)
      end

      it "is allowed when user created multiple posts in PMs to themself" do
        topic = Fabricate(:private_message_topic, user: user, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user)
        ])

        Fabricate(:post, user: user, topic: topic)
        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)
      end

      it "isn't allowed when user created multiple posts in PMs sent to other users" do
        topic = Fabricate(:private_message_topic, user: user, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user),
          Fabricate.build(:topic_allowed_user, user: Fabricate(:user))
        ])

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(false)
      end

      it "isn't allowed when user created multiple posts in PMs sent to groups" do
        topic = Fabricate(:private_message_topic, user: user, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user)
        ], topic_allowed_groups: [
          Fabricate.build(:topic_allowed_group, group: Fabricate(:group)),
          Fabricate.build(:topic_allowed_group, group: Fabricate(:group))
        ])

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(true)

        Fabricate(:post, user: user, topic: topic)
        expect(guardian.can_delete_user?(user)).to eq(false)
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
end
