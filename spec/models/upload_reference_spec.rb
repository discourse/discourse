# frozen_string_literal: true

RSpec.describe UploadReference do
  describe "badge uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      badge = nil
      expect { badge = Fabricate(:badge, image_upload_id: upload.id) }.to change {
        UploadReference.count
      }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(badge)

      expect { badge.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "category uploads" do
    fab!(:upload1) { Fabricate(:upload) }
    fab!(:upload2) { Fabricate(:upload) }
    fab!(:upload3) { Fabricate(:upload) }

    it "creates upload references" do
      category = nil
      expect {
        category =
          Fabricate(
            :category,
            uploaded_logo_id: upload1.id,
            uploaded_logo_dark_id: upload2.id,
            uploaded_background_id: upload3.id,
          )
      }.to change { UploadReference.count }.by(3)

      upload_reference = UploadReference.last
      expect(upload_reference.target).to eq(category)

      expect { category.destroy! }.to change { UploadReference.count }.by(-3)
    end
  end

  describe "custom emoji uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      custom_emoji = nil
      expect { custom_emoji = CustomEmoji.create!(name: "emoji", upload_id: upload.id) }.to change {
        UploadReference.count
      }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.target).to eq(custom_emoji)

      expect { custom_emoji.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "group uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      group = nil
      expect { group = Fabricate(:group, flair_upload_id: upload.id) }.to change {
        UploadReference.count
      }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(group)

      expect { group.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "post uploads" do
    fab!(:upload) { Fabricate(:upload) }
    fab!(:post) { Fabricate(:post, raw: "[](#{upload.short_url})") }

    it "creates upload references" do
      expect { post.link_post_uploads }.to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(post)

      expect { post.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "site setting uploads" do
    let(:provider) { SiteSettings::DbProvider.new(SiteSetting) }
    fab!(:upload) { Fabricate(:upload) }
    fab!(:upload2) { Fabricate(:upload) }

    it "creates upload references for uploads" do
      expect {
        provider.save("logo", upload.id, SiteSettings::TypeSupervisor.types[:upload])
      }.to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(SiteSetting.find_by(name: "logo"))

      expect { provider.destroy("logo") }.to change { UploadReference.count }.by(-1)
    end

    it "creates upload references for uploaded_image_lists" do
      expect {
        provider.save(
          "selectable_avatars",
          "#{upload.id}|#{upload2.id}",
          SiteSettings::TypeSupervisor.types[:uploaded_image_list],
        )
      }.to change { UploadReference.count }.by(2)

      upload_references =
        UploadReference.all.where(target: SiteSetting.find_by(name: "selectable_avatars"))
      expect(upload_references.pluck(:upload_id)).to contain_exactly(upload.id, upload2.id)

      expect { provider.destroy("selectable_avatars") }.to change { UploadReference.count }.by(-2)
    end
  end

  describe "theme field uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      theme_field = nil
      expect do
        theme_field =
          ThemeField.create!(
            theme_id: Fabricate(:theme).id,
            target_id: 0,
            name: "field",
            value: "",
            upload: upload,
            type_id: ThemeField.types[:theme_upload_var],
          )
      end.to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(theme_field)

      expect { theme_field.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "theme setting uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      theme_setting = nil
      expect do
        theme_setting =
          ThemeSetting.create!(
            name: "field",
            data_type: ThemeSetting.types[:upload],
            value: upload.id,
            theme_id: Fabricate(:theme).id,
          )
      end.to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(theme_setting)

      expect { theme_setting.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "user uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      user = nil
      expect { user = Fabricate(:user, uploaded_avatar_id: upload.id) }.to change {
        UploadReference.count
      }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(user)

      expect { user.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "user avatar uploads" do
    fab!(:upload1) { Fabricate(:upload) }
    fab!(:upload2) { Fabricate(:upload) }

    it "creates upload references" do
      user_avatar = nil
      expect {
        user_avatar =
          Fabricate(:user_avatar, custom_upload_id: upload1.id, gravatar_upload_id: upload2.id)
      }.to change { UploadReference.count }.by(2)

      upload_reference = UploadReference.last
      expect(upload_reference.target).to eq(user_avatar)

      expect { user_avatar.destroy! }.to change { UploadReference.count }.by(-2)
    end
  end

  describe "user export uploads" do
    fab!(:upload) { Fabricate(:upload) }

    it "creates upload references" do
      user_export = nil
      expect do
        user_export =
          UserExport.create!(
            file_name: "export",
            user: Fabricate(:user),
            upload: upload,
            topic: Fabricate(:topic),
          )
      end.to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(user_export)

      expect { user_export.destroy! }.to change { UploadReference.count }.by(-1)
    end
  end

  describe "user profile uploads" do
    fab!(:user) { Fabricate(:user) }
    fab!(:upload1) { Fabricate(:upload) }
    fab!(:upload2) { Fabricate(:upload) }

    it "creates upload references" do
      user_profile = user.user_profile
      expect {
        user_profile.update!(
          profile_background_upload_id: upload1.id,
          card_background_upload_id: upload2.id,
        )
      }.to change { UploadReference.count }.by(2)

      upload_reference = UploadReference.last
      expect(upload_reference.target).to eq(user_profile)

      expect { user_profile.destroy! }.to change { UploadReference.count }.by(-2)
    end
  end
end
