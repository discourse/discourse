require 'rails_helper'

require_dependency 'jobs/scheduled/clean_up_uploads'

describe Jobs::CleanUpUploads do

  def fabricate_upload(attributes = {})
    Fabricate(:upload, { created_at: 2.hours.ago }.merge(attributes))
  end

  let(:upload) { fabricate_upload }

  before do
    SiteSetting.clean_up_uploads = true
    SiteSetting.clean_orphan_uploads_grace_period_hours = 1
    @upload = fabricate_upload
  end

  it "deletes orphan uploads" do
    expect do
      Jobs::CleanUpUploads.new.execute(nil)
    end.to change { Upload.count }.by(-1)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
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

      expect(Upload.exists?(id: @upload.id)).to eq(true)
      expect(Upload.exists?(id: upload2.id)).to eq(false)
    end
  end

  it "does not clean up uploads in site settings" do
    logo_upload = fabricate_upload
    SiteSetting.logo_url = logo_upload.url

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: logo_upload.id)).to eq(true)
  end

  it "does not clean up uploads in site settings when they use the CDN" do
    Discourse.stubs(:asset_host).returns("//my.awesome.cdn")

    logo_small_upload = fabricate_upload
    SiteSetting.logo_small_url = "#{Discourse.asset_host}#{logo_small_upload.url}"

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: logo_small_upload.id)).to eq(true)
  end

  it "does not delete profile background uploads" do
    profile_background_upload = fabricate_upload
    UserProfile.last.update_attributes!(profile_background: profile_background_upload.url)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: profile_background_upload.id)).to eq(true)
  end

  it "does not delete card background uploads" do
    card_background_upload = fabricate_upload
    UserProfile.last.update_attributes!(card_background: card_background_upload.url)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: card_background_upload.id)).to eq(true)
  end

  it "does not delete category logo uploads" do
    category_logo_upload = fabricate_upload
    Fabricate(:category, uploaded_logo: category_logo_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: category_logo_upload.id)).to eq(true)
  end

  it "does not delete category background url uploads" do
    category_logo_upload = fabricate_upload
    Fabricate(:category, uploaded_background: category_logo_upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: category_logo_upload.id)).to eq(true)
  end

  it "does not delete post uploads" do
    upload = fabricate_upload
    Fabricate(:post, uploads: [upload])

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user uploaded avatar" do
    upload = fabricate_upload
    Fabricate(:user, uploaded_avatar: upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user gravatar" do
    upload = fabricate_upload
    Fabricate(:user, user_avatar: Fabricate(:user_avatar, gravatar_upload: upload))

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user custom upload" do
    upload = fabricate_upload
    Fabricate(:user, user_avatar: Fabricate(:user_avatar, custom_upload: upload))

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete uploads in a queued post" do
    upload = fabricate_upload
    upload2 = fabricate_upload

    QueuedPost.create(
      queue: "uploads",
      state: QueuedPost.states[:new],
      user_id: Fabricate(:user).id,
      raw: "#{upload.sha1}\n#{upload2.short_url}",
      post_options: {}
    )

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
    expect(Upload.exists?(id: upload2.id)).to eq(true)
  end

  it "does not delete uploads in a draft" do
    upload = fabricate_upload
    upload2 = fabricate_upload

    Draft.set(Fabricate(:user), "test", 0, "#{upload.sha1}\n#{upload2.short_url}")

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
    expect(Upload.exists?(id: upload2.id)).to eq(true)
  end

  it "does not delete custom emojis" do
    upload = fabricate_upload
    CustomEmoji.create!(name: 'test', upload: upload)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: upload.id)).to eq(true)
  end

  it "does not delete user exported csv uploads" do
    csv_file = fabricate_upload
    UserExport.create(file_name: "export.csv", user_id: Fabricate(:user).id, upload_id: csv_file.id)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.exists?(id: @upload.id)).to eq(false)
    expect(Upload.exists?(id: csv_file.id)).to eq(true)
  end
end
