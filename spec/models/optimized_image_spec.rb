require 'spec_helper'

describe OptimizedImage do

  it { should belong_to :upload }

  let(:upload) { Fabricate(:upload) }
  let(:oi) { OptimizedImage.create_for(upload, 100, 200) }

  describe ".create_for" do

    before { ImageSorcery.any_instance.expects(:convert).returns(true) }

    describe "internal store" do

      it "works" do
        Tempfile.any_instance.expects(:close!)
        oi.sha1.should == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
        oi.extension.should == ".jpg"
        oi.width.should == 100
        oi.height.should == 200
        oi.url.should == "/uploads/default/_optimized/da3/9a3/ee5e6b4b0d_100x200.jpg"
      end

    end

    describe "external store" do

      require 'file_store/s3_store'
      require 'fog'

      let(:store) { S3Store.new }

      before do
        Discourse.stubs(:store).returns(store)
        SiteSetting.stubs(:s3_upload_bucket).returns("S3_Upload_Bucket")
        SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
        SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
        Fog.mock!
      end

      it "works" do
        # fake downloaded file
        downloaded_file = {}
        downloaded_file.expects(:path).returns("/path/to/fake.png")
        downloaded_file.expects(:close!)
        store.expects(:download).returns(downloaded_file)
        # assertions
        oi.sha1.should == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
        oi.extension.should == ".png"
        oi.width.should == 100
        oi.height.should == 200
        oi.url.should =~ /^\/\/s3_upload_bucket.s3.amazonaws.com\/[0-9a-f]+_100x200.png/
      end

    end

  end

end
