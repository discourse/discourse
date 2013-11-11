require "spec_helper"
require "avatar_upload_service"

describe AvatarUploadService do
  let(:file) do
    ActionDispatch::Http::UploadedFile.new({
      filename: 'logo.png',
      tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
    })
  end

  let(:url) { "http://cdn.discourse.org/assets/logo.png" }

  describe "#construct" do
    context "when avatar is in the form of a file upload" do
      let(:avatar_file) { AvatarUploadService.new(file, :image) }

      it "should have a filesize" do
        expect(avatar_file.filesize).to eq(2290)
      end

      it "should have a source as 'image'" do
        expect(avatar_file.source).to eq(:image)
      end

      it "is an instance of File class" do
        file = avatar_file.file
        expect(file.tempfile).to be_instance_of File
      end

      it "returns the file object built from File" do
        file = avatar_file.file
        file.should be_instance_of(ActionDispatch::Http::UploadedFile)
        file.original_filename.should == "logo.png"
      end
    end

    context "when file is in the form of a URL" do
      let(:avatar_file) { AvatarUploadService.new(url, :url) }

      before :each do
        UriAdapter.any_instance.stubs(:open).returns StringIO.new(fixture_file("images/logo.png"))
      end

      it "should have a filesize" do
        expect(avatar_file.filesize).to eq(2290)
      end

      it "should have a source as 'url'" do
        expect(avatar_file.source).to eq(:url)
      end

      it "is an instance of Tempfile class" do
        file = avatar_file.file
        expect(file.tempfile).to be_instance_of Tempfile
      end

      it "returns the file object built from URL" do
        file = avatar_file.file
        file.should be_instance_of(ActionDispatch::Http::UploadedFile)
        file.original_filename.should == "logo.png"
      end
    end
  end

end
