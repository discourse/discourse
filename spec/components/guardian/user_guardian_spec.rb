require 'rails_helper'

describe UserGuardian do

  let :user do
    Fabricate.build(:user, id: 1)
  end

  let :moderator do
    Fabricate.build(:moderator, id: 2)
  end

  let :admin do
    Fabricate.build(:admin, id: 3)
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
      let(:user) { Fabricate(:user) }

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
      Fabricate.build(:user, id: 4)
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
end
