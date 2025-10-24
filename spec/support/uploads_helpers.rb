# frozen_string_literal: true

module UploadsHelpers
  def setup_s3
    SiteSetting.s3_upload_bucket = "bucket"
    SiteSetting.enable_s3_uploads = true

    SiteSetting.s3_region = "us-west-1"
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"

    SiteSetting.s3_access_key_id = "some key"
    SiteSetting.s3_secret_access_key = "some secrets3_region key"

    dualstack = SiteSetting.Upload.use_dualstack_endpoint ? ".dualstack" : ""

    stub_request(
      :head,
      "https://#{SiteSetting.s3_upload_bucket}.s3#{dualstack}.#{SiteSetting.s3_region}.amazonaws.com/",
    )
  end

  def enable_secure_uploads
    setup_s3
    SiteSetting.secure_uploads = true
  end

  def stub_upload(upload)
    dualstack = SiteSetting.Upload.use_dualstack_endpoint ? ".dualstack" : ""

    url =
      %r{https://#{SiteSetting.s3_upload_bucket}.s3#{dualstack}.#{SiteSetting.s3_region}.amazonaws.com/original/\d+X.*#{upload.sha1}.#{upload.extension}\?acl}
    stub_request(:put, url)
  end

  def stub_s3_store
    store = FileStore::S3Store.new
    client = Aws::S3::Client.new(stub_responses: true)
    store.s3_helper.stubs(:s3_client).returns(client)
    Discourse.stubs(:store).returns(store)
  end
end
