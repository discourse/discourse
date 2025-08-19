# frozen_string_literal: true

RSpec.describe Jobs::CleanUpUploads do
  def fabricate_upload(attributes = {})
    Fabricate(:upload, { created_at: 2.hours.ago }.merge(attributes))
  end

  fab! :expired_upload do
    fabricate_upload
  end

  before do
    SiteSetting.clean_up_uploads = true
    SiteSetting.clean_orphan_uploads_grace_period_hours = 1

    # pre-fabrication resets created_at, so re-expire the upload
    expired_upload
    freeze_time 2.hours.from_now

    Jobs::CleanUpUploads.new.reset_last_cleanup!
  end

  it "only runs upload cleanup every grace period / 2 time" do
    SiteSetting.clean_orphan_uploads_grace_period_hours = 48
    expired = fabricate_upload(created_at: 49.hours.ago)
    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired.id)).to eq(false)

    upload = fabricate_upload(created_at: 72.hours.ago)
    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: upload.id)).to eq(true)

    freeze_time 25.hours.from_now

    Jobs::CleanUpUploads.new.execute(nil)
    expect(Upload.exists?(id: upload.id)).to eq(false)
  end

  it "deletes orphan uploads" do
    expect do Jobs::CleanUpUploads.new.execute(nil) end.to change { Upload.count }.by(-1)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
  end

  describe "unused callbacks" do
    before { Upload.add_unused_callback { |uploads| uploads.where.not(id: expired_upload.id) } }

    after { Upload.reset_unused_callbacks }

    it "does not delete uploads skipped by an unused callback" do
      expect do Jobs::CleanUpUploads.new.execute(nil) end.not_to change { Upload.count }

      expect(Upload.exists?(id: expired_upload.id)).to eq(true)
    end

    it "deletes other uploads not skipped by an unused callback" do
      expired_upload2 = fabricate_upload
      upload = fabricate_upload
      UploadReference.create(target: Fabricate(:post), upload: upload)

      expect do Jobs::CleanUpUploads.new.execute(nil) end.to change { Upload.count }.by(-1)

      expect(Upload.exists?(id: expired_upload.id)).to eq(true)
      expect(Upload.exists?(id: expired_upload2.id)).to eq(false)
      expect(Upload.exists?(id: upload.id)).to eq(true)
    end
  end

  describe "in use callbacks" do
    before { Upload.add_in_use_callback { |upload| expired_upload.id == upload.id } }

    after { Upload.reset_in_use_callbacks }

    it "does not delete uploads that are in use by callback" do
      expect do Jobs::CleanUpUploads.new.execute(nil) end.not_to change { Upload.count }

      expect(Upload.exists?(id: expired_upload.id)).to eq(true)
    end

    it "deletes other uploads that are not in use by callback" do
      expired_upload2 = fabricate_upload
      upload = fabricate_upload
      UploadReference.create(target: Fabricate(:post), upload: upload)

      expect do Jobs::CleanUpUploads.new.execute(nil) end.to change { Upload.count }.by(-1)

      expect(Upload.exists?(id: expired_upload.id)).to eq(true)
      expect(Upload.exists?(id: expired_upload2.id)).to eq(false)
      expect(Upload.exists?(id: upload.id)).to eq(true)
    end
  end

  describe "when clean_up_uploads is disabled" do
    before { SiteSetting.clean_up_uploads = false }

    it "should still delete invalid upload records" do
      upload2 = fabricate_upload(url: "", retain_hours: nil)

      expect do Jobs::CleanUpUploads.new.execute(nil) end.to change { Upload.count }.by(-1)

      expect(Upload.exists?(id: expired_upload.id)).to eq(true)
      expect(Upload.exists?(id: upload2.id)).to eq(false)
    end
  end

  it "does not clean up upload site settings" do
    begin
      original_provider = SiteSetting.provider
      SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
      SiteSetting.clean_orphan_uploads_grace_period_hours = 1

      system_upload = fabricate_upload(id: -999)
      logo_upload = fabricate_upload
      logo_small_upload = fabricate_upload
      digest_logo_upload = fabricate_upload
      mobile_logo_upload = fabricate_upload
      large_icon_upload = fabricate_upload
      opengraph_image_upload = fabricate_upload
      x_summary_large_image_upload = fabricate_upload
      favicon_upload = fabricate_upload
      apple_touch_icon_upload = fabricate_upload

      SiteSetting.logo = logo_upload
      SiteSetting.logo_small = logo_small_upload
      SiteSetting.digest_logo = digest_logo_upload
      SiteSetting.mobile_logo = mobile_logo_upload
      SiteSetting.large_icon = large_icon_upload
      SiteSetting.opengraph_image = opengraph_image_upload

      SiteSetting.x_summary_large_image = x_summary_large_image_upload

      SiteSetting.favicon = favicon_upload
      SiteSetting.apple_touch_icon = apple_touch_icon_upload

      Jobs::CleanUpUploads.new.execute(nil)

      [
        logo_upload,
        logo_small_upload,
        digest_logo_upload,
        mobile_logo_upload,
        large_icon_upload,
        opengraph_image_upload,
        x_summary_large_image_upload,
        favicon_upload,
        apple_touch_icon_upload,
        system_upload,
      ].each { |record| expect(Upload.exists?(id: record.id)).to eq(true) }

      fabricate_upload
      SiteSetting.opengraph_image = ""

      Jobs::CleanUpUploads.new.execute(nil)
    ensure
      SiteSetting.delete_all
      SiteSetting.provider = original_provider
    end
  end

  it "does not clean up selectable avatars" do
    original_provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
    SiteSetting.clean_orphan_uploads_grace_period_hours = 1

    avatar1_upload = fabricate_upload
    avatar2_upload = fabricate_upload

    SiteSetting.selectable_avatars = [avatar1_upload, avatar2_upload]

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: avatar1_upload.id)).to eq(true)
    expect(Upload.exists?(id: avatar2_upload.id)).to eq(true)
  ensure
    SiteSetting.delete_all
    SiteSetting.provider = original_provider
  end

  it "does not delete profile background uploads" do
    profile_background_upload = fabricate_upload
    UserProfile.last.upload_profile_background(profile_background_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: profile_background_upload.id)).to eq(true)
  end

  it "does not delete card background uploads" do
    card_background_upload = fabricate_upload
    UserProfile.last.upload_card_background(card_background_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: card_background_upload.id)).to eq(true)
  end

  it "does not delete category logo uploads" do
    category_logo_upload = fabricate_upload
    Fabricate(:category, uploaded_logo: category_logo_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: category_logo_upload.id)).to eq(true)
  end

  it "does not delete category dark logo uploads" do
    category_logo_dark_upload = fabricate_upload
    Fabricate(:category, uploaded_logo_dark: category_logo_dark_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: category_logo_dark_upload.id)).to eq(true)
  end

  it "does not delete category background uploads" do
    category_background_upload = fabricate_upload
    Fabricate(:category, uploaded_background: category_background_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: category_background_upload.id)).to eq(true)
  end

  it "does not delete category dark background uploads" do
    category_background_dark_upload = fabricate_upload
    Fabricate(:category, uploaded_background_dark: category_background_dark_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: category_background_dark_upload.id)).to eq(true)
  end

  it "does not delete post uploads" do
    upload = fabricate_upload
    Fabricate(:post, uploads: [upload])

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user uploaded avatar" do
    upload = fabricate_upload
    Fabricate(:user, uploaded_avatar: upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user gravatar" do
    upload = fabricate_upload
    Fabricate(:user, user_avatar: Fabricate(:user_avatar, gravatar_upload: upload))

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user custom upload" do
    upload = fabricate_upload
    Fabricate(:user, user_avatar: Fabricate(:user_avatar, custom_upload: upload))

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete uploads in a queued post" do
    upload = fabricate_upload
    upload2 = fabricate_upload
    upload3 = fabricate_upload

    Fabricate(
      :reviewable_queued_post_topic,
      payload: {
        raw: "#{upload.short_url}\n#{upload2.short_url}",
      },
      status: :pending,
    )

    Fabricate(
      :reviewable_queued_post_topic,
      payload: {
        raw: "#{upload3.short_url}",
      },
      status: :rejected,
    )

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
    expect(Upload.exists?(id: upload2.id)).to eq(true)
    expect(Upload.exists?(id: upload3.id)).to eq(false)
  end

  it "does not delete uploads in a draft" do
    upload = fabricate_upload
    upload2 = fabricate_upload

    Draft.set(Fabricate(:user), "test", 0, "upload://#{upload.sha1}\n#{upload2.short_url}")

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
    expect(Upload.exists?(id: upload2.id)).to eq(true)
  end

  it "does not delete uploads with an access control post ID that are marked secure" do
    secure_upload = fabricate_upload(access_control_post_id: Fabricate(:post).id, secure: true)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: secure_upload.id)).to eq(true)
  end

  it "does delete uploads with an access control post ID that are not marked secure" do
    secure_upload = fabricate_upload(access_control_post_id: Fabricate(:post).id, secure: false)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: secure_upload.id)).to eq(false)
  end

  it "does not delete custom emojis" do
    upload = fabricate_upload
    CustomEmoji.create!(name: "test", upload: upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user exported csv uploads" do
    csv_file = fabricate_upload
    UserExport.create(file_name: "export.csv", user_id: Fabricate(:user).id, upload_id: csv_file.id)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: csv_file.id)).to eq(true)
  end

  it "does not delete theme setting uploads" do
    theme = Fabricate(:theme)
    theme_upload = fabricate_upload
    ThemeSetting.create!(
      theme: theme,
      data_type: ThemeSetting.types[:upload],
      value: theme_upload.id.to_s,
      name: "my_setting_name",
    )

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: theme_upload.id)).to eq(true)
  end

  it "does not delete badges uploads" do
    badge_image = fabricate_upload
    badge = Fabricate(:badge, image_upload_id: badge_image.id)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: badge_image.id)).to eq(true)
  end

  it "deletes external upload stubs that have expired" do
    external_stub1 =
      Fabricate(
        :external_upload_stub,
        status: ExternalUploadStub.statuses[:created],
        created_at: 10.minutes.ago,
      )
    external_stub2 =
      Fabricate(
        :external_upload_stub,
        status: ExternalUploadStub.statuses[:created],
        created_at: (ExternalUploadStub::CREATED_EXPIRY_HOURS.hours + 10.minutes).ago,
      )
    external_stub3 =
      Fabricate(
        :external_upload_stub,
        status: ExternalUploadStub.statuses[:uploaded],
        created_at: 10.minutes.ago,
      )
    external_stub4 =
      Fabricate(
        :external_upload_stub,
        status: ExternalUploadStub.statuses[:uploaded],
        created_at: (ExternalUploadStub::UPLOADED_EXPIRY_HOURS.hours + 10.minutes).ago,
      )
    Jobs::CleanUpUploads.new.execute(nil)
    expect(ExternalUploadStub.pluck(:id)).to contain_exactly(external_stub1.id, external_stub3.id)
  end

  it "does not delete create external upload stubs for 2 days if debug mode is on" do
    SiteSetting.enable_upload_debug_mode = true
    external_stub1 =
      Fabricate(
        :external_upload_stub,
        status: ExternalUploadStub.statuses[:created],
        created_at: 2.hours.ago,
      )
    Jobs::CleanUpUploads.new.execute(nil)
    expect(ExternalUploadStub.pluck(:id)).to contain_exactly(external_stub1.id)

    SiteSetting.enable_upload_debug_mode = false
    Jobs::CleanUpUploads.new.execute(nil)
    expect(ExternalUploadStub.pluck(:id)).to be_empty
  end
end
