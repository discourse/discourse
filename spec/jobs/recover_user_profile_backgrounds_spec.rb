require 'rails_helper'

require_dependency 'jobs/onceoff/recover_user_profile_backgrounds'

RSpec.describe Jobs::RecoverUserProfileBackgrounds do
  let(:user_profile) { Fabricate(:user).user_profile }

  before do
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "s3-access-key-id"
    SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    SiteSetting.enable_s3_uploads = true
  end

  it "corrects the URL and recovers the uploads" do
    current_upload = Upload.create!(
      url: '//s3-upload-bucket.s3-us-east-1.amazonaws.com/somewhere/a.png',
      original_filename: 'a.png',
      filesize: 100,
      user_id: -1,
    )

    user_profile.update!(
      profile_background: current_upload.url,
      card_background: current_upload.url
    )

    Jobs::RecoverUserProfileBackgrounds.new.execute_onceoff({})

    user_profile.reload

    %i{card_background profile_background}.each do |column|
      expect(user_profile.public_send(column)).to eq(
        '//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/somewhere/a.png'
      )
    end

  end
end
