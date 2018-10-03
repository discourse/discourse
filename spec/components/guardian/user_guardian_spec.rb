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

  let :user_avatar do
    UserAvatar.new(user_id: user.id)
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
        expect(guardian.can_pick_avatar?(user_avatar, not_my_upload)).to eq(false)
        expect(guardian.can_pick_avatar?(user_avatar, nil)).to eq(true)
      end

      it "can handle uploads that are associated but not directly owned" do
        yes_my_upload = not_my_upload
        UserUpload.create!(upload_id: yes_my_upload.id, user_id: user_avatar.user_id)
        expect(guardian.can_pick_avatar?(user_avatar, yes_my_upload)).to eq(true)

        UserUpload.destroy_all

        UserUpload.create!(upload_id: yes_my_upload.id, user_id: yes_my_upload.user_id)
        expect(guardian.can_pick_avatar?(user_avatar, yes_my_upload)).to eq(true)
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
end
