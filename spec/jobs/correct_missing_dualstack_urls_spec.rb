require 'rails_helper'

require_dependency 'jobs/onceoff/correct_missing_dualstack_urls'

describe Jobs::CorrectMissingDualstackUrls do

  it 'corrects the urls' do

    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "s3-access-key-id"
    SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    SiteSetting.enable_s3_uploads = true

    # we will only correct for our base_url, random urls will be left alone
    expect(Discourse.store.absolute_base_url).to eq('//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com')

    current_upload = Upload.create!(
      url: '//s3-upload-bucket.s3-us-east-1.amazonaws.com/somewhere/a.png',
      original_filename: 'a.png',
      filesize: 100,
      user_id: -1,
    )

    bad_upload = Upload.create!(
      url: '//s3-upload-bucket.s3-us-west-1.amazonaws.com/somewhere/a.png',
      original_filename: 'a.png',
      filesize: 100,
      user_id: -1,
    )

    current_optimized = OptimizedImage.create!(
      url: '//s3-upload-bucket.s3-us-east-1.amazonaws.com/somewhere/a.png',
      filesize: 100,
      upload_id: current_upload.id,
      width: 100,
      height: 100,
      sha1: 'xxx',
      extension: '.png'
    )

    bad_optimized = OptimizedImage.create!(
      url: '//s3-upload-bucket.s3-us-west-1.amazonaws.com/somewhere/a.png',
      filesize: 100,
      upload_id: current_upload.id,
      width: 110,
      height: 100,
      sha1: 'xxx',
      extension: '.png'
    )

    Jobs::CorrectMissingDualstackUrls.new.execute_onceoff(nil)

    bad_upload.reload
    expect(bad_upload.url).to eq('//s3-upload-bucket.s3-us-west-1.amazonaws.com/somewhere/a.png')

    current_upload.reload
    expect(current_upload.url).to eq('//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/somewhere/a.png')

    bad_optimized.reload
    expect(bad_optimized.url).to eq('//s3-upload-bucket.s3-us-west-1.amazonaws.com/somewhere/a.png')

    current_optimized.reload
    expect(current_optimized.url).to eq('//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/somewhere/a.png')
  end
end
