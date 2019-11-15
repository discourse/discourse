# frozen_string_literal: true

require 'rails_helper'

describe Jobs::CleanUpUploads do

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
    expect do
      Jobs::CleanUpUploads.new.execute(nil)
    end.to change { Upload.count }.by(-1)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
  end

  describe 'when clean_up_uploads is disabled' do
    before do
      SiteSetting.clean_up_uploads = false
    end

    it 'should still delete invalid upload records' do
      upload2 = fabricate_upload(
        url: "",
        retain_hours: nil
      )

      expect do
        Jobs::CleanUpUploads.new.execute(nil)
      end.to change { Upload.count }.by(-1)

      expect(Upload.exists?(id: expired_upload.id)).to eq(true)
      expect(Upload.exists?(id: upload2.id)).to eq(false)
    end
  end

  it 'does not clean up upload site settings' do
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
      twitter_summary_large_image_upload = fabricate_upload
      favicon_upload = fabricate_upload
      apple_touch_icon_upload = fabricate_upload

      SiteSetting.logo = logo_upload
      SiteSetting.logo_small = logo_small_upload
      SiteSetting.digest_logo = digest_logo_upload
      SiteSetting.mobile_logo = mobile_logo_upload
      SiteSetting.large_icon = large_icon_upload
      SiteSetting.opengraph_image = opengraph_image_upload

      SiteSetting.twitter_summary_large_image =
        twitter_summary_large_image_upload

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
        twitter_summary_large_image_upload,
        favicon_upload,
        apple_touch_icon_upload,
        system_upload
      ].each { |record| expect(Upload.exists?(id: record.id)).to eq(true) }

      fabricate_upload
      SiteSetting.opengraph_image = ''

      Jobs::CleanUpUploads.new.execute(nil)
    ensure
      SiteSetting.delete_all
      SiteSetting.provider = original_provider
    end
  end

  it "does not clean up uploads with URLs used in site settings" do
    logo_upload = fabricate_upload
    logo_small_upload = fabricate_upload
    digest_logo_upload = fabricate_upload
    mobile_logo_upload = fabricate_upload
    large_icon_upload = fabricate_upload
    default_opengraph_image_upload = fabricate_upload
    twitter_summary_large_image_upload = fabricate_upload
    favicon_upload = fabricate_upload
    apple_touch_icon_upload = fabricate_upload
    avatar1_upload = fabricate_upload
    avatar2_upload = fabricate_upload

    SiteSetting.logo_url = logo_upload.url
    SiteSetting.logo_small_url = logo_small_upload.url
    SiteSetting.digest_logo_url = digest_logo_upload.url
    SiteSetting.mobile_logo_url = mobile_logo_upload.url
    SiteSetting.large_icon_url = large_icon_upload.url
    SiteSetting.default_opengraph_image_url = default_opengraph_image_upload.url

    SiteSetting.twitter_summary_large_image_url =
      twitter_summary_large_image_upload.url

    SiteSetting.favicon_url = favicon_upload.url
    SiteSetting.apple_touch_icon_url = apple_touch_icon_upload.url
    SiteSetting.selectable_avatars = [avatar1_upload.url, avatar2_upload.url].join("\n")

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: logo_upload.id)).to eq(true)
    expect(Upload.exists?(id: logo_small_upload.id)).to eq(true)
    expect(Upload.exists?(id: digest_logo_upload.id)).to eq(true)
    expect(Upload.exists?(id: mobile_logo_upload.id)).to eq(true)
    expect(Upload.exists?(id: large_icon_upload.id)).to eq(true)
    expect(Upload.exists?(id: default_opengraph_image_upload.id)).to eq(true)
    expect(Upload.exists?(id: twitter_summary_large_image_upload.id)).to eq(true)
    expect(Upload.exists?(id: favicon_upload.id)).to eq(true)
    expect(Upload.exists?(id: apple_touch_icon_upload.id)).to eq(true)
    expect(Upload.exists?(id: avatar1_upload.id)).to eq(true)
    expect(Upload.exists?(id: avatar2_upload.id)).to eq(true)
  end

  it "does not clean up uploads in site settings when they use the CDN" do
    Discourse.stubs(:asset_host).returns("//my.awesome.cdn")

    logo_small_upload = fabricate_upload
    SiteSetting.logo_small_url = "#{Discourse.asset_host}#{logo_small_upload.url}"

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: logo_small_upload.id)).to eq(true)
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

  it "does not delete category background url uploads" do
    category_logo_upload = fabricate_upload
    Fabricate(:category, uploaded_background: category_logo_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: category_logo_upload.id)).to eq(true)
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

    Fabricate(:reviewable_queued_post_topic, payload: {
      raw: "#{upload.sha1}\n#{upload2.short_url}"
    })

    Fabricate(:reviewable_queued_post_topic,
      payload: {
        raw: "#{upload3.sha1}"
      },
      status: Reviewable.statuses[:rejected]
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

    Draft.set(Fabricate(:user), "test", 0, "#{upload.sha1}\n#{upload2.short_url}")

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: expired_upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
    expect(Upload.exists?(id: upload2.id)).to eq(true)
  end

  it "does not delete custom emojis" do
    upload = fabricate_upload
    CustomEmoji.create!(name: 'test', upload: upload)

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
end
