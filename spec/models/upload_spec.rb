require 'spec_helper'
require 'digest/sha1'

describe Upload do

  it { should belong_to :user }

  it { should have_many :post_uploads }
  it { should have_many :posts }

  it { should have_many :optimized_images }

  it { should validate_presence_of :original_filename }
  it { should validate_presence_of :filesize }

  context '.create_for' do

    let(:user_id) { 1 }

    let(:logo) do
      ActionDispatch::Http::UploadedFile.new({
        filename: 'logo.png',
        content_type: 'image/png',
        tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
      })
    end

    let(:upload) { Upload.create_for(user_id, logo) }

    let(:url) { "http://domain.com" }

    shared_examples_for "upload" do
      it "is valid" do
        upload.user_id.should == user_id
        upload.original_filename.should == logo.original_filename
        upload.filesize.should == File.size(logo.tempfile)
        upload.sha1.should == Digest::SHA1.file(logo.tempfile).hexdigest
        upload.width.should == 244
        upload.height.should == 66
        upload.url.should == url
      end
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

  context 'has_been_uploaded?' do

    it "identifies internal or relatives urls" do
      Discourse.expects(:base_url_no_prefix).returns("http://discuss.site.com")
      Upload.has_been_uploaded?("http://discuss.site.com/uploads/default/42/0123456789ABCDEF.jpg").should == true
      Upload.has_been_uploaded?("/upload/42/0123456789ABCDEF.jpg").should == true
    end

    it "identifies internal urls when using a CDN" do
      ActionController::Base.expects(:asset_host).returns("http://my.cdn.com").twice
      Upload.has_been_uploaded?("http://my.cdn.com/uploads/default/42/0123456789ABCDEF.jpg").should == true
    end

    it "identifies S3 uploads" do
      SiteSetting.stubs(:enable_s3_uploads).returns(true)
      SiteSetting.stubs(:s3_upload_bucket).returns("bucket")
      Upload.has_been_uploaded?("//bucket.s3.amazonaws.com/1337.png").should == true
    end

    it "identifies external urls" do
      Upload.has_been_uploaded?("http://domain.com/uploads/default/42/0123456789ABCDEF.jpg").should == false
      Upload.has_been_uploaded?("//bucket.s3.amazonaws.com/1337.png").should == false
    end

  end

end
