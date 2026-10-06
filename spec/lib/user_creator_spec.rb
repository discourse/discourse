# frozen_string_literal: true

describe UserCreator do
  fab!(:admin)
  fab!(:moderator)

  describe ".create" do
    it "creates an active and approved user and records the staff action" do
      created_user = nil

      expect do
        created_user =
          described_class.create(
            admin.guardian,
            username: "new_cat",
            email: "new-cat@example.com",
            name: "New 猫",
            password: "correct horse battery staple",
            active: true,
            approved: true,
          )
      end.to change(User, :count).by(1).and change {
              UserHistory.where(
                action: UserHistory.actions[:custom_staff],
                custom_type: "create_user",
                acting_user_id: admin.id,
              ).count
            }.by(1)

      expect(created_user).to be_persisted
      expect(created_user).to be_active.and be_approved
      expect(created_user).to be_email_confirmed
    end

    it "preserves requested inactive and unapproved state" do
      created_user =
        described_class.create(
          admin.guardian,
          username: "pending_cat",
          email: "pending-cat@example.com",
          name: "Pending Cat",
          password: "correct horse battery staple",
          active: false,
          approved: false,
        )

      expect(created_user).to be_persisted
      expect(created_user).not_to be_active
      expect(created_user).not_to be_approved
    end

    it "assigns an uploaded avatar through the existing avatar permission" do
      upload = Fabricate(:upload, user: admin)

      created_user =
        described_class.create(
          admin.guardian,
          username: "avatar_cat",
          email: "avatar-cat@example.com",
          name: "Avatar Cat",
          password: "correct horse battery staple",
          upload_id: upload.id,
        )

      expect(created_user.reload.uploaded_avatar_id).to eq(upload.id)
      expect(created_user.user_avatar.custom_upload_id).to eq(upload.id)
    end

    it "does not create the user when authentication controls avatars" do
      SiteSetting.auth_overrides_avatar = true
      upload = Fabricate(:upload, user: admin)

      expect do
        described_class.create(
          admin.guardian,
          username: "managed_avatar_cat",
          email: "managed-avatar-cat@example.com",
          name: "Managed Avatar Cat",
          password: "correct horse battery staple",
          upload_id: upload.id,
        )
      end.to raise_error(Discourse::InvalidAccess).and not_change(User, :count)
    end

    it "does not create the user when the user cannot upload an avatar" do
      SiteSetting.uploaded_avatars_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      upload = Fabricate(:upload, user: admin)

      expect do
        described_class.create(
          admin.guardian,
          username: "restricted_cat",
          email: "restricted-avatar-cat@example.com",
          name: "Restricted Avatar Cat",
          password: "correct horse battery staple",
          upload_id: upload.id,
        )
      end.to raise_error(Discourse::InvalidAccess).and not_change(User, :count)
    end

    it "requires an administrator even when the caller is staff" do
      expect do
        described_class.create(
          moderator.guardian,
          username: "not_created",
          email: "not-created@example.com",
          name: "Not Created",
          password: "correct horse battery staple",
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect(User.find_by_username("not_created")).to be_nil
    end

    it "returns validation errors without recording a staff action" do
      existing_user = Fabricate(:user)
      created_user = nil

      expect do
        created_user =
          described_class.create(
            admin.guardian,
            username: existing_user.username,
            email: "different@example.com",
            name: "Duplicate",
            password: "correct horse battery staple",
          )
      end.not_to change {
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_user",
          acting_user_id: admin.id,
        ).count
      }

      expect(created_user).not_to be_persisted
      expect(created_user.errors).to be_present
    end

    it "does not unstage an existing user when the requested attributes are invalid" do
      existing_user = Fabricate(:user)
      staged_user = Fabricate(:staged, email: "staged-cat@example.com")

      created_user =
        described_class.create(
          admin.guardian,
          username: existing_user.username,
          email: staged_user.email,
          name: "Staged Cat",
          password: "correct horse battery staple",
        )

      expect(created_user.errors).to be_present
      expect(staged_user.reload).to be_staged
      expect(staged_user.username).not_to eq(existing_user.username)
    end
  end
end
