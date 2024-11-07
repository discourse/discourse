# frozen_string_literal: true

require "s3_helper"

RSpec.describe "S3Helper" do
  let(:client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    setup_s3

    @lifecycle = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <LifecycleConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <Rule>
            <ID>old_rule</ID>
            <Prefix>projectdocs/</Prefix>
            <Status>Enabled</Status>
            <Expiration>
               <Days>3650</Days>
            </Expiration>
        </Rule>
        <Rule>
            <ID>purge-tombstone</ID>
            <Prefix>test/</Prefix>
            <Status>Enabled</Status>
            <Expiration>
               <Days>3650</Days>
            </Expiration>
        </Rule>
      </LifecycleConfiguration>
    XML
  end

  it "can correctly set the purge policy" do
    SiteSetting.s3_configure_tombstone_policy = true

    stub_request(
      :get,
      "http://169.254.169.254/latest/meta-data/iam/security-credentials/",
    ).to_return(status: 404, body: "", headers: {})

    stub_request(
      :get,
      "https://bob.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/?lifecycle",
    ).to_return(status: 200, body: @lifecycle, headers: {})

    stub_request(:put, "https://bob.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/?lifecycle")
      .with do |req|
        hash = Hash.from_xml(req.body.to_s)
        rules = hash["LifecycleConfiguration"]["Rule"]

        expect(rules.length).to eq(2)
        expect(rules[1]["Expiration"]["Days"]).to eq("100")
        # fixes the bad filter
        expect(rules[0]["Filter"]["Prefix"]).to eq("projectdocs/")
      end
      .to_return(status: 200, body: "", headers: {})

    helper = S3Helper.new("bob", "tomb")
    helper.update_tombstone_lifecycle(100)
  end

  it "can skip policy update when s3_configure_tombstone_policy is false" do
    SiteSetting.s3_configure_tombstone_policy = false

    helper = S3Helper.new("bob", "tomb")
    helper.update_tombstone_lifecycle(100)
  end

  describe "#list" do
    it "creates the prefix correctly" do
      { "some/bucket" => "bucket/testing", "some" => "testing" }.each do |bucket_name, prefix|
        s3_helper = S3Helper.new(bucket_name, "", client: client)
        Aws::S3::Bucket.any_instance.expects(:objects).with({ prefix: prefix })
        s3_helper.list("testing")
      end
    end
  end

  it "should prefix bucket folder path only if not exists" do
    s3_helper = S3Helper.new("bucket/folder_path", "", client: client)

    object1 = s3_helper.object("original/1X/def.xyz")
    object2 = s3_helper.object("folder_path/original/1X/def.xyz")

    expect(object1.key).to eq(object2.key)
  end

  it "should not prefix the bucket folder path if the key begins with the temporary upload prefix" do
    s3_helper = S3Helper.new("bucket/folder_path", "", client: client)

    object1 = s3_helper.object("original/1X/def.xyz")
    object2 =
      s3_helper.object(
        "#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}folder_path/uploads/default/blah/def.xyz",
      )

    expect(object1.key).to eq("folder_path/original/1X/def.xyz")
    expect(object2.key).to eq(
      "#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}folder_path/uploads/default/blah/def.xyz",
    )
  end

  describe "#copy" do
    let(:source_key) do
      "#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}uploads/default/blah/source.jpg"
    end
    let(:destination_key) { "original/1X/destination.jpg" }
    let(:s3_helper) { S3Helper.new("test-bucket", "", client: client) }

    it "can copy a small object from the source to the destination" do
      source_stub = Aws::S3::Object.new(bucket_name: "test-bucket", key: source_key, client: client)
      source_stub.stubs(:size).returns(5 * 1024 * 1024)
      s3_helper.send(:s3_bucket).expects(:object).with(source_key).returns(source_stub)

      destination_stub =
        Aws::S3::Object.new(bucket_name: "test-bucket", key: destination_key, client: client)
      s3_helper.send(:s3_bucket).expects(:object).with(destination_key).returns(destination_stub)

      destination_stub
        .expects(:copy_from)
        .with(source_stub, {})
        .returns(stub(copy_object_result: stub(etag: '"etag"')))

      response = s3_helper.copy(source_key, destination_key)
      expect(response.first).to eq(destination_key)
      expect(response.second).to eq("etag")
    end

    it "can copy a large object from the source to the destination" do
      source_stub = Aws::S3::Object.new(bucket_name: "test-bucket", key: source_key, client: client)
      source_stub.stubs(:size).returns(20 * 1024 * 1024)
      s3_helper.send(:s3_bucket).expects(:object).with(source_key).returns(source_stub)

      destination_stub =
        Aws::S3::Object.new(bucket_name: "test-bucket", key: destination_key, client: client)
      s3_helper.send(:s3_bucket).expects(:object).with(destination_key).returns(destination_stub)

      options = { multipart_copy: true, content_length: source_stub.size }
      destination_stub
        .expects(:copy_from)
        .with(source_stub, options)
        .returns(stub(data: stub(etag: '"etag"')))

      response = s3_helper.copy(source_key, destination_key)
      expect(response.first).to eq(destination_key)
      expect(response.second).to eq("etag")
    end

    it "puts the metadata from options onto the destination if apply_metadata_to_destination" do
      source_stub = Aws::S3::Object.new(bucket_name: "test-bucket", key: source_key, client: client)
      source_stub.stubs(:size).returns(5 * 1024 * 1024)
      s3_helper.send(:s3_bucket).expects(:object).with(source_key).returns(source_stub)

      destination_stub =
        Aws::S3::Object.new(bucket_name: "test-bucket", key: destination_key, client: client)
      s3_helper.send(:s3_bucket).expects(:object).with(destination_key).returns(destination_stub)

      content_disposition = "attachment; filename=\"source.jpg\"; filename*=UTF-8''source.jpg"
      options = { content_disposition: content_disposition, metadata_directive: "REPLACE" }
      destination_stub
        .expects(:copy_from)
        .with(source_stub, options)
        .returns(stub(data: stub(etag: '"etag"')))

      response =
        s3_helper.copy(
          source_key,
          destination_key,
          options: {
            apply_metadata_to_destination: true,
            content_disposition: content_disposition,
          },
        )
      expect(response.first).to eq(destination_key)
      expect(response.second).to eq("etag")
    end
  end

  describe "#ensure_cors" do
    let(:s3_helper) { S3Helper.new("test-bucket", "", client: client) }

    it "does nothing if !s3_install_cors_rule" do
      SiteSetting.s3_install_cors_rule = false
      s3_helper.expects(:s3_resource).never
      s3_helper.ensure_cors!
    end

    it "creates the assets rule if no rule exists" do
      s3_helper.s3_client.stub_responses(
        :get_bucket_cors,
        Aws::S3::Errors::NoSuchCORSConfiguration.new("", {}),
      )
      s3_helper
        .s3_client
        .expects(:put_bucket_cors)
        .with(
          bucket: s3_helper.s3_bucket_name,
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
      s3_helper.ensure_cors!([S3CorsRulesets::ASSETS])
    end

    it "does nothing if a rule already exists" do
      s3_helper.s3_client.stub_responses(:get_bucket_cors, { cors_rules: [S3CorsRulesets::ASSETS] })
      s3_helper.s3_client.expects(:put_bucket_cors).never
      s3_helper.ensure_cors!([S3CorsRulesets::ASSETS])
    end

    it "applies the passed in rule if a different rule already exists" do
      s3_helper.s3_client.stub_responses(:get_bucket_cors, { cors_rules: [S3CorsRulesets::ASSETS] })
      s3_helper
        .s3_client
        .expects(:put_bucket_cors)
        .with(
          bucket: s3_helper.s3_bucket_name,
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS, S3CorsRulesets::BACKUP_DIRECT_UPLOAD],
          },
        )
      s3_helper.ensure_cors!([S3CorsRulesets::BACKUP_DIRECT_UPLOAD])
    end

    it "returns false if the CORS rules do not get applied from an error" do
      s3_helper.s3_client.stub_responses(:get_bucket_cors, { cors_rules: [S3CorsRulesets::ASSETS] })
      s3_helper
        .s3_client
        .expects(:put_bucket_cors)
        .with(
          bucket: s3_helper.s3_bucket_name,
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS, S3CorsRulesets::BACKUP_DIRECT_UPLOAD],
          },
        )
        .raises(Aws::S3::Errors::AccessDenied.new("test", "test", {}))
      expect(s3_helper.ensure_cors!([S3CorsRulesets::BACKUP_DIRECT_UPLOAD])).to eq(false)
    end
  end

  describe "#delete_objects" do
    let(:s3_helper) { S3Helper.new("test-bucket", "", client: client) }

    it "works" do
      # The S3::Client with `stub_responses: true` includes validation of requests.
      # If the request were invalid, this spec would raise an error
      s3_helper.delete_objects(%w[object/one.txt object/two.txt])
    end
  end

  describe "#presigned_url" do
    let(:s3_helper) { S3Helper.new("test-bucket", "", client: client) }

    it "uses the S3 dualstack endpoint" do
      expect(s3_helper.presigned_url("test/key.jpeg", method: :get_object)).to include("dualstack")
    end

    context "for a China S3 region" do
      before { SiteSetting.s3_region = "cn-northwest-1" }

      it "does not use the S3 dualstack endpoint" do
        expect(s3_helper.presigned_url("test/key.jpeg", method: :get_object)).not_to include(
          "dualstack",
        )
      end
    end
  end

  describe "#presigned_request" do
    let(:s3_helper) { S3Helper.new("test-bucket", "", client: client) }

    it "uses the S3 dualstack endpoint" do
      expect(s3_helper.presigned_request("test/key.jpeg", method: :get_object)[0]).to include(
        "dualstack",
      )
    end

    context "for a China S3 region" do
      before { SiteSetting.s3_region = "cn-northwest-1" }

      it "does not use the S3 dualstack endpoint" do
        expect(s3_helper.presigned_request("test/key.jpeg", method: :get_object)[0]).not_to include(
          "dualstack",
        )
      end
    end
  end
end
