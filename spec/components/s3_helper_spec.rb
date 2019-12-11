# frozen_string_literal: true

require "s3_helper"
require "rails_helper"

describe "S3Helper" do
  let(:client) { Aws::S3::Client.new(stub_responses: true) }

  before(:each) do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.s3_region = "us-east-1"

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

    stub_request(:get, "https://bob.s3.amazonaws.com/?lifecycle").
      to_return(status: 200, body: @lifecycle, headers: {})

    stub_request(:put, "https://bob.s3.amazonaws.com/?lifecycle").
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
    s3_helper = S3Helper.new('bucket/folder_path', "", client: client)

    object1 = s3_helper.object("original/1X/def.xyz")
    object2 = s3_helper.object("folder_path/original/1X/def.xyz")

    expect(object1.key).to eq(object2.key)
  end
end
