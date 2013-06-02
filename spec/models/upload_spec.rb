require 'spec_helper'
require 'fog'
require 'imgur'

describe Upload do

  it { should belong_to :user }
  it { should belong_to :topic }

  it { should validate_presence_of :original_filename }
  it { should validate_presence_of :filesize }

  context '.create_for' do

    let(:user_id) { 1 }
    let(:topic_id) { 42 }

    let(:logo) do
      ActionDispatch::Http::UploadedFile.new({
        filename: 'logo.png',
        content_type: 'image/png',
        tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
      })
    end

    it "uses imgur when it is enabled" do
      SiteSetting.stubs(:enable_imgur?).returns(true)
      Upload.expects(:create_on_imgur).with(user_id, logo, topic_id)
      Upload.create_for(user_id, logo, topic_id)
    end

    it "uses s3 when it is enabled" do
      SiteSetting.stubs(:enable_s3_uploads?).returns(true)
      Upload.expects(:create_on_s3).with(user_id, logo, topic_id)
      Upload.create_for(user_id, logo, topic_id)
    end

    it "uses local storage otherwise" do
      Upload.expects(:create_locally).with(user_id, logo, topic_id)
      Upload.create_for(user_id, logo, topic_id)
    end

    shared_examples_for "upload" do
      it "is valid" do
        upload.original_filename.should == logo.original_filename
        upload.filesize.should == logo.size
        upload.width.should == 244
        upload.height.should == 66
      end
    end

    context 'imgur' do

      before(:each) do
        # Stub out Imgur entirely as it already is tested.
        Imgur.stubs(:upload_file).returns({
          url: "imgurlink",
          filesize: logo.size,
          width: 244,
          height: 66
        })
      end

      let(:upload) { Upload.create_on_imgur(user_id, logo, topic_id) }

      it_behaves_like "upload"

      it "works" do
        upload.url.should == "imgurlink"
      end

    end

    context 's3' do

      before(:each) do 
        SiteSetting.stubs(:s3_upload_bucket).returns("bucket")
        Fog.mock!
      end

      let(:upload) { Upload.create_on_s3(user_id, logo, topic_id) }

      it_behaves_like "upload"

      it "works" do
        upload.url.should == "//bucket.s3-us-west-1.amazonaws.com/e8b1353813a7d091231f9a27f03566f123463fc1.png"
      end

      after(:each) do
        Fog.unmock!
      end

    end

    context 'local' do

      before(:each) do
        # prevent the tests from creating directories & files...
        FileUtils.stubs(:mkdir_p)
        File.stubs(:open)
      end

      let(:upload) do
        # The Time needs to be frozen as it is used to generate a clean & unique name
        Time.stubs(:now).returns(Time.utc(2013, 2, 17, 12, 0, 0, 0))
        Upload.create_locally(user_id, logo, topic_id)
      end

      it_behaves_like "upload"

      it "works" do
        upload.url.should match /\/uploads\/default\/[\d]+\/253dc8edf9d4ada1.png/
      end

    end

  end

end
