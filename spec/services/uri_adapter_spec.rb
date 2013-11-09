require 'spec_helper'

describe UriAdapter do
  let(:target) { "http://cdn.discourse.org/assets/logo.png" }
  let(:response) { StringIO.new(fixture_file("images/logo.png")) }

  before :each do
    response.stubs(:content_type).returns("image/png")
    UriAdapter.any_instance.stubs(:open).returns(response)
  end

  subject { UriAdapter.new(target) }

  describe "#initialize" do

    it "has a target" do
      subject.target.should be_instance_of(URI::HTTP)
    end

    it "has content" do
      subject.content.should == response
    end

    it "has an original_filename" do
      subject.original_filename.should == "logo.png"
    end

    it "has a tempfile" do
      subject.tempfile.should be_instance_of Tempfile
    end

  end

  describe "#copy_to_tempfile" do
    it "does not allow files bigger then max_image_size_kb" do
      SiteSetting.stubs(:max_image_size_kb).returns(1)
      subject.build_uploaded_file.should == nil
    end
  end

  describe "#build_uploaded_file" do
    it "returns an uploaded file" do
      file = subject.build_uploaded_file
      file.should be_instance_of(ActionDispatch::Http::UploadedFile)
      file.content_type.should == "image/png"
      file.original_filename.should == "logo.png"
      file.tempfile.should be_instance_of Tempfile
    end
  end

end