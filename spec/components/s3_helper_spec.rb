# frozen_string_literal: true

require "rails_helper"
require "s3_helper"

describe "S3Helper" do
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

    stub_request(:get, "http://169.254.169.254/latest/meta-data/iam/security-credentials/").
      to_return(status: 404, body: "", headers: {})

    stub_request(:get, "https://bob.s3.#{SiteSetting.s3_region}.amazonaws.com/?lifecycle").
      to_return(status: 200, body: @lifecycle, headers: {})

    stub_request(:put, "https://bob.s3.#{SiteSetting.s3_region}.amazonaws.com/?lifecycle").
      with do |req|

      hash = Hash.from_xml(req.body.to_s)
      rules = hash["LifecycleConfiguration"]["Rule"]

      expect(rules.length).to eq(2)
      expect(rules[1]["Expiration"]["Days"]).to eq("100")
      # fixes the bad filter
      expect(rules[0]["Filter"]["Prefix"]).to eq("projectdocs/")
    end.to_return(status: 200, body: "", headers: {})

    helper = S3Helper.new('bob', 'tomb')
    helper.update_tombstone_lifecycle(100)
  end

  it "can skip policy update when s3_configure_tombstone_policy is false" do
    SiteSetting.s3_configure_tombstone_policy = false

    helper = S3Helper.new('bob', 'tomb')
    helper.update_tombstone_lifecycle(100)
  end

  describe '#list' do
    it 'creates the prefix correctly' do
      {
        'some/bucket' => 'bucket/testing',
        'some' => 'testing'
      }.each do |bucket_name, prefix|
        s3_helper = S3Helper.new(bucket_name, "", client: client)
        Aws::S3::Bucket.any_instance.expects(:objects).with(prefix: prefix)
        s3_helper.list('testing')
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
    object2 = s3_helper.object("#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}folder_path/uploads/default/blah/def.xyz")

    expect(object1.key).to eq("folder_path/original/1X/def.xyz")
    expect(object2.key).to eq("#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}folder_path/uploads/default/blah/def.xyz")
  end

  describe "#copy" do
    let(:source_key) { "#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}uploads/default/blah/source.jpg" }
    let(:destination_key) { "original/1X/destination.jpg" }
    let(:s3_helper) { S3Helper.new("test-bucket", "", client: client) }

    it "can copy an object from the source to the destination" do
      destination_stub = Aws::S3::Object.new(bucket_name: "test-bucket", key: destination_key, client: client)
      s3_helper.send(:s3_bucket).expects(:object).with(destination_key).returns(destination_stub)
      destination_stub.expects(:copy_from).with(copy_source: "test-bucket/#{source_key}").returns(
        stub(copy_object_result: stub(etag: "\"etag\""))
      )
      response = s3_helper.copy(source_key, destination_key)
      expect(response.first).to eq(destination_key)
      expect(response.second).to eq("etag")
    end

    it "puts the metadata from options onto the destination if apply_metadata_to_destination" do
      content_disposition = "attachment; filename=\"source.jpg\"; filename*=UTF-8''source.jpg"
      destination_stub = Aws::S3::Object.new(bucket_name: "test-bucket", key: destination_key, client: client)
      s3_helper.send(:s3_bucket).expects(:object).with(destination_key).returns(destination_stub)
      destination_stub.expects(:copy_from).with(
        copy_source: "test-bucket/#{source_key}", content_disposition: content_disposition, metadata_directive: "REPLACE"
      ).returns(
        stub(copy_object_result: stub(etag: "\"etag\""))
      )
      response = s3_helper.copy(
        source_key, destination_key,
        options: { apply_metadata_to_destination: true, content_disposition: content_disposition }
      )
      expect(response.first).to eq(destination_key)
      expect(response.second).to eq("etag")
    end
  end
end
