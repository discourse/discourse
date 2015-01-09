require "s3_helper"
require "spec_helper"

describe "S3Helper" do

  before(:each) do
    SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
    SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
    Fog.mock!
    Fog::Mock.reset
    Fog::Mock.delay = 0
  end

  after(:each) do
    Fog.unmock!
  end


  let(:s3_bucket) { "s3_bucket_name" }
  let(:tombstone_prefix) { nil }
  let(:fog) { stub }
  let(:s3) { S3Helper.new(s3_bucket, tombstone_prefix, fog) }

  let(:filename) { "logo.png" }
  let(:file) { file_from_fixtures(filename) }

  it "ensures the bucket name isn't blank" do
    expect { S3Helper.new("") }.to raise_error(Discourse::InvalidParameters)
  end

  describe ".upload" do

    let(:fog) { nil }

    it "works" do
      result = s3.upload(file, filename)
      expect(result).to be_a Fog::Storage::AWS::File
    end

  end

  describe ".remove" do

    context "without tombstone prefix" do

      it "only deletes the object even when asked to copy it to the tombstone" do
        fog.expects(:copy_object).never
        fog.expects(:delete_object).with(s3_bucket, filename)
        s3.remove(filename, true)
      end

    end

    context "with tombstone prefix" do

      let(:tombstone_prefix) { "tombstone/" }

      it "only deletes the object by default" do
        fog.expects(:copy_object).never
        fog.expects(:delete_object).with(s3_bucket, filename)
        s3.remove(filename)
      end

      it "copies the object to the tombstone and deletes it when asked for" do
        fog.expects(:copy_object)
        fog.expects(:delete_object).with(s3_bucket, filename)
        s3.remove(filename, true)
      end

    end

  end

  describe ".update_tombstone_lifecycle" do

    context "without tombstone prefix" do

      it "doesn't call put_bucket_lifecycle" do
        fog.expects(:put_bucket_lifecycle).never
        s3.update_tombstone_lifecycle(3.days)
      end

    end

    context "with tombstone prefix" do

      let(:tombstone_prefix) { "tombstone/" }

      it "calls put_bucket_lifecycle" do
        fog.expects(:put_bucket_lifecycle)
        s3.update_tombstone_lifecycle(3.days)
      end

    end

  end

end
