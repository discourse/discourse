require 'spec_helper'

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

    let(:upload) { Upload.create_for(user_id, logo, topic_id) }

    let(:url) { "http://domain.com" }

    shared_examples_for "upload" do
      it "is valid" do
        upload.user_id.should == user_id
        upload.topic_id.should == topic_id
        upload.original_filename.should == logo.original_filename
        upload.filesize.should == File.size(logo.tempfile)
        upload.width.should == 244
        upload.height.should == 66
        upload.url.should == url
      end
    end

    context "imgur" do
      before(:each) do
        SiteSetting.stubs(:enable_imgur?).returns(true)
        Imgur.stubs(:store_file).returns(url)
      end

      it_behaves_like "upload"

    end

    context "s3" do
      before(:each) do 
        SiteSetting.stubs(:enable_s3_uploads?).returns(true)
        S3.stubs(:store_file).returns(url)
      end

      it_behaves_like "upload"

    end

    context "locally" do
      before(:each) { LocalStore.stubs(:store_file).returns(url) }
      it_behaves_like "upload"
    end

  end

end
