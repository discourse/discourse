require "spec_helper"
require "avatar_upload_service"

describe AvatarUploadService do

  let(:logo) { File.new("#{Rails.root}/spec/fixtures/images/logo.png") }

  let(:file) do
    ActionDispatch::Http::UploadedFile.new({ filename: 'logo.png', tempfile: logo })
  end

  let(:url) { "http://cdn.discourse.org/assets/logo.png" }

  describe "#construct" do
    context "when avatar is in the form of a file upload" do
      let(:avatar_file) { AvatarUploadService.new(file, :image) }

      it "should have a filesize" do
        avatar_file.filesize.should == 2290
      end

      it "should have a filename" do
        avatar_file.filename.should == "logo.png"
      end

      it "should have a file" do
        avatar_file.file.should == file.tempfile
      end

      it "should have a source as 'image'" do
        avatar_file.source.should == :image
      end
    end

    context "when file is in the form of a URL" do
      let(:avatar_file) { AvatarUploadService.new(url, :url) }

      before { FileHelper.stubs(:download).returns(logo) }

      it "should have a filesize" do
        avatar_file.filesize.should == 2290
      end

      it "should have a filename" do
        avatar_file.filename.should == "logo.png"
      end

      it "should have a file" do
        avatar_file.file.should == logo
      end

      it "should have a source as 'url'" do
        avatar_file.source.should == :url
      end
    end
  end

end
