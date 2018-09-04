require 'rails_helper'

describe OptimizedImage do
  let(:upload) { build(:upload) }
  before { upload.id = 42 }

  unless ENV["TRAVIS"]
    describe '.crop' do
      it 'should work correctly' do
        tmp_path = "/tmp/cropped.png"

        begin
          OptimizedImage.crop(
            "#{Rails.root}/spec/fixtures/images/logo.png",
            tmp_path,
            5,
            5
          )

          expect(File.read(tmp_path)).to eq(
            File.read("#{Rails.root}/spec/fixtures/images/cropped.png")
          )
        ensure
          File.delete(tmp_path) if File.exists?(tmp_path)
        end
      end
    end

    describe '.resize' do
      it 'should work correctly when extension is bad' do

        original_path = Dir::Tmpname.create(['origin', '.bin']) { nil }

        begin
          FileUtils.cp "#{Rails.root}/spec/fixtures/images/logo.png", original_path

          # we use "filename" to get the correct extension here, it is more important
          # then any other param

          OptimizedImage.resize(
            original_path,
            original_path,
            5,
            5,
            filename: "test.png"
          )

          expect(File.read(original_path)).to eq(
            File.read("#{Rails.root}/spec/fixtures/images/resized.png")
          )
        ensure
          File.delete(original_path) if File.exists?(original_path)
        end
      end

      it 'should work correctly' do

        file = File.open("#{Rails.root}/spec/fixtures/images/resized.png")
        upload = UploadCreator.new(file, "test.bin").create_for(-1)

        expect(upload.filesize).to eq(199)

        expect(upload.width).to eq(5)
        expect(upload.height).to eq(5)

        upload.create_thumbnail!(10, 10)
        thumb = upload.thumbnail(10, 10)

        expect(thumb.width).to eq(10)
        expect(thumb.height).to eq(10)

        # very image magic specific so fudge here
        expect(thumb.filesize).to be > 200

        # this size is based off original upload
        # it is the size we render, by default, in the post
        expect(upload.thumbnail_width).to eq(5)
        expect(upload.thumbnail_height).to eq(5)

        # lets ensure we can rebuild the filesize
        thumb.update_columns(filesize: nil)
        thumb = OptimizedImage.find(thumb.id)

        # attempts to auto correct
        expect(thumb.filesize).to be > 200
      end

      describe 'when an svg with a href is masked as a png' do
        it 'should not trigger the external request' do
          tmp_path = "/tmp/resized.png"

          begin
            expect do
              OptimizedImage.resize(
                "#{Rails.root}/spec/fixtures/images/svg.png",
                tmp_path,
                5,
                5,
                raise_on_error: true
              )
            end.to raise_error(RuntimeError, /improper image header/)
          ensure
            File.delete(tmp_path) if File.exists?(tmp_path)
          end
        end
      end
    end

    describe '.downsize' do
      it 'should work correctly' do
        tmp_path = "/tmp/downsized.png"

        begin
          OptimizedImage.downsize(
            "#{Rails.root}/spec/fixtures/images/logo.png",
            tmp_path,
            "100x100\>"
          )

          expect(File.read(tmp_path)).to eq(
            File.read("#{Rails.root}/spec/fixtures/images/downsized.png")
          )
        ensure
          File.delete(tmp_path) if File.exists?(tmp_path)
        end
      end
    end
  end

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

    it "raises InvalidAccess error on paths" do
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
