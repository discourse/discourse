require 'spec_helper'

describe OptimizedImage do

  it { should belong_to :upload }

  let(:upload) { build(:upload) }

  before { upload.id = 42 }

  describe ".create_for" do

    context "when using an internal store" do

      let(:store) { FakeInternalStore.new }
      before { Discourse.stubs(:store).returns(store) }

      context "when an error happened while generatign the thumbnail" do

        before { ImageSorcery.any_instance.stubs(:convert).returns(false) }

        it "returns nil" do
          OptimizedImage.create_for(upload, 100, 200).should be_nil
        end

      end

      context "when the thumbnail is properly generated" do

        before { ImageSorcery.any_instance.stubs(:convert).returns(true) }

        it "does not download a copy of the original image" do
          store.expects(:download).never
          OptimizedImage.create_for(upload, 100, 200)
        end

        it "closes and removes the tempfile" do
          Tempfile.any_instance.expects(:close!)
          OptimizedImage.create_for(upload, 100, 200)
        end

        it "works" do
          oi = OptimizedImage.create_for(upload, 100, 200)
          oi.sha1.should == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
          oi.extension.should == ".jpg"
          oi.width.should == 100
          oi.height.should == 200
          oi.url.should == "/internally/stored/optimized/image.jpg"
        end

      end

    end

    describe "external store" do

      let(:store) { FakeExternalStore.new }
      before { Discourse.stubs(:store).returns(store) }

      context "when an error happened while generatign the thumbnail" do

        before { ImageSorcery.any_instance.stubs(:convert).returns(false) }

        it "returns nil" do
          OptimizedImage.create_for(upload, 100, 200).should be_nil
        end

      end

      context "when the thumbnail is properly generated" do

        before { ImageSorcery.any_instance.stubs(:convert).returns(true) }

        it "downloads a copy of the original image" do
          Tempfile.any_instance.expects(:close!).twice
          store.expects(:download).with(upload).returns(Tempfile.new(["discourse-external", ".jpg"]))
          OptimizedImage.create_for(upload, 100, 200)
        end

        it "works" do
          oi = OptimizedImage.create_for(upload, 100, 200)
          oi.sha1.should == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
          oi.extension.should == ".jpg"
          oi.width.should == 100
          oi.height.should == 200
          oi.url.should == "/externally/stored/optimized/image.jpg"
        end

      end

    end

  end

end

class FakeInternalStore

  def internal?
    true
  end

  def external?
    !internal?
  end

  def path_for(upload)
    upload.url
  end

  def store_optimized_image(file, optimized_image)
    "/internally/stored/optimized/image#{optimized_image.extension}"
  end

end

class FakeExternalStore

  def external?
    true
  end

  def internal?
    !external?
  end

  def store_optimized_image(file, optimized_image)
    "/externally/stored/optimized/image#{optimized_image.extension}"
  end

  def download(upload)
    extension = File.extname(upload.original_filename)
    Tempfile.new(["discourse-s3", extension])
  end

end
