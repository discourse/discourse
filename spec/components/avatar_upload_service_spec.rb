require "spec_helper"
require "avatar_upload_service"

describe AvatarUploadService do

  let(:logo) { file_from_fixtures("logo.png") }

  let(:file) do
    ActionDispatch::Http::UploadedFile.new({ filename: 'logo.png', tempfile: logo })
  end

  let(:url) { "http://cdn.discourse.org/assets/logo.png" }

  describe "#construct" do
    context "when avatar is in the form of a file upload" do
      let(:avatar_file) { AvatarUploadService.new(file, :image) }

      it "should have a filesize" do
        expect(avatar_file.filesize).to be > 0
      end

      it "should have a filename" do
        expect(avatar_file.filename).to eq("logo.png")
      end

      it "should have a file" do
        expect(avatar_file.file).to eq(file.tempfile)
      end

      it "should have a source as 'image'" do
        expect(avatar_file.source).to eq(:image)
      end
    end

    context "when file is in the form of a URL" do
      let(:avatar_file) { AvatarUploadService.new(url, :url) }

      before { FileHelper.stubs(:download).returns(logo) }

      it "should have a filesize" do
        expect(avatar_file.filesize).to be > 0
      end

      it "should have a filename" do
        expect(avatar_file.filename).to eq("logo.png")
      end

      it "should have a file" do
        expect(avatar_file.file).to eq(logo)
      end

      it "should have a source as 'url'" do
        expect(avatar_file.source).to eq(:url)
      end
    end
  end

end
