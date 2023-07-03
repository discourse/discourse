# frozen_string_literal: true

describe "Uploading files to S3", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  before do
    SiteSetting.enable_s3_uploads = true

    SiteSetting.s3_upload_bucket = "discoursetestbucket"
    SiteSetting.enable_upload_debug_mode = true

    SiteSetting.s3_access_key_id = "minioadmin"
    SiteSetting.s3_secret_access_key = "minioadmin"
    SiteSetting.s3_endpoint = "http://127.0.0.1:9000"

    sign_in(current_user)
  end

  describe "direct S3 uploads (non-multipart)" do
    before { SiteSetting.enable_direct_s3_uploads = true }

    xit "uploads custom avatars to S3" do
      visit "/my/preferences/account"

      find("#edit-avatar").click
      find("#uploaded-avatar").click
      attach_file(File.absolute_path(file_from_fixtures("logo.png"))) do
        find("#avatar-uploader").click
      end
      expect(current_user.reload.uploaded_avatar_id).to be_present
    end
  end
end
