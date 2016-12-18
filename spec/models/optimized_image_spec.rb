require 'rails_helper'

describe OptimizedImage do

  let(:upload) { build(:upload) }
  before { upload.id = 42 }

  describe ".safe_path?" do

    it "correctly detects unsafe paths" do
      expect(OptimizedImage.safe_path?("/path/A-AA/22_00.TIFF")).to eq(true)
      expect(OptimizedImage.safe_path?("/path/AAA/2200.TIFF")).to eq(true)
      expect(OptimizedImage.safe_path?("/tmp/a.png")).to eq(true)
      expect(OptimizedImage.safe_path?("../a.png")).to eq(false)
      expect(OptimizedImage.safe_path?("/tmp/a.png\\test")).to eq(false)
      expect(OptimizedImage.safe_path?("/tmp/a.png\\test")).to eq(false)
      expect(OptimizedImage.safe_path?("/path/\u1000.png")).to eq(false)
      expect(OptimizedImage.safe_path?("/path/x.png\n")).to eq(false)
      expect(OptimizedImage.safe_path?("/path/x.png\ny.png")).to eq(false)
      expect(OptimizedImage.safe_path?("/path/x.png y.png")).to eq(false)
      expect(OptimizedImage.safe_path?(nil)).to eq(false)
    end

  end

  describe "ensure_safe_paths!" do
    it "raises nothing on safe paths" do
      expect {
        OptimizedImage.ensure_safe_paths!("/a.png", "/b.png")
      }.not_to raise_error
    end

    it "raises nothing on paths" do
      expect {
        OptimizedImage.ensure_safe_paths!("/a.png", "/b.png", "c.png")
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe ".local?" do

    def local(url)
      OptimizedImage.new(url: url).local?
    end

    it "correctly detects local vs remote" do
      expect(local("//hello")).to eq(false)
      expect(local("http://hello")).to eq(false)
      expect(local("https://hello")).to eq(false)
      expect(local("https://hello")).to eq(false)
      expect(local("/hello")).to eq(true)
    end
  end

  describe ".create_for" do

    context "when using an internal store" do

      let(:store) { FakeInternalStore.new }
      before { Discourse.stubs(:store).returns(store) }

      context "when an error happened while generating the thumbnail" do

        it "returns nil" do
          OptimizedImage.expects(:resize).returns(false)
          expect(OptimizedImage.create_for(upload, 100, 200)).to eq(nil)
        end

      end

      context "when the thumbnail is properly generated" do

        before do
          OptimizedImage.expects(:resize).returns(true)
        end

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
          expect(oi.sha1).to eq("da39a3ee5e6b4b0d3255bfef95601890afd80709")
          expect(oi.extension).to eq(".png")
          expect(oi.width).to eq(100)
          expect(oi.height).to eq(200)
          expect(oi.url).to eq("/internally/stored/optimized/image.png")
        end

      end

    end

    describe "external store" do

      let(:store) { FakeExternalStore.new }
      before { Discourse.stubs(:store).returns(store) }

      context "when an error happened while generatign the thumbnail" do

        it "returns nil" do
          OptimizedImage.expects(:resize).returns(false)
          expect(OptimizedImage.create_for(upload, 100, 200)).to eq(nil)
        end

      end

      context "when the thumbnail is properly generated" do

        before do
          OptimizedImage.expects(:resize).returns(true)
        end

        it "downloads a copy of the original image" do
          Tempfile.any_instance.expects(:close!)
          store.expects(:download).with(upload).returns(Tempfile.new(["discourse-external", ".png"]))
          OptimizedImage.create_for(upload, 100, 200)
        end

        it "works" do
          oi = OptimizedImage.create_for(upload, 100, 200)
          expect(oi.sha1).to eq("da39a3ee5e6b4b0d3255bfef95601890afd80709")
          expect(oi.extension).to eq(".png")
          expect(oi.width).to eq(100)
          expect(oi.height).to eq(200)
          expect(oi.url).to eq("/externally/stored/optimized/image.png")
        end

      end

    end

  end

end

class FakeInternalStore

  def external?
    false
  end

  def path_for(upload)
    upload.url
  end

  def store_optimized_image(file, optimized_image)
    "/internally/stored/optimized/image#{optimized_image.extension}"
  end

end

class FakeExternalStore

  def path_for(upload)
    nil
  end

  def external?
    true
  end

  def store_optimized_image(file, optimized_image)
    "/externally/stored/optimized/image#{optimized_image.extension}"
  end

  def download(upload)
    extension = File.extname(upload.original_filename)
    Tempfile.new(["discourse-s3", extension])
  end

end
