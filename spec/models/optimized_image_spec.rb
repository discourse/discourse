# frozen_string_literal: true

require 'rails_helper'

describe OptimizedImage do
  let(:upload) { build(:upload) }
  before { upload.id = 42 }

  describe '.crop' do
    it 'should produce cropped images (requires ImageMagick 7)' do
      tmp_path = "/tmp/cropped.png"

      begin
        OptimizedImage.crop(
          "#{Rails.root}/spec/fixtures/images/logo.png",
          tmp_path,
          5,
          5
        )

        # we don't want to deal with something new here every time image magick
        # is upgraded or pngquant is upgraded, lets just test the basics ...
        # cropped image should be less than 120 bytes

        cropped_size = File.size(tmp_path)

        expect(cropped_size).to be < 120
        expect(cropped_size).to be > 50

      ensure
        File.delete(tmp_path) if File.exist?(tmp_path)
      end
    end

    describe ".resize_instructions" do
      let(:image) { "#{Rails.root}/spec/fixtures/images/logo.png" }

      it "doesn't return any color options by default" do
        instructions = described_class.resize_instructions(image, image, "50x50")
        expect(instructions).to_not include('-colors')
      end

      it "supports an optional color option" do
        instructions = described_class.resize_instructions(image, image, "50x50", colors: 12)
        expect(instructions).to include('-colors')
      end

    end

    describe '.resize' do
      it 'should work correctly when extension is bad' do

        original_path = Dir::Tmpname.create(['origin', '.bin']) { nil }

        begin
          FileUtils.cp "#{Rails.root}/spec/fixtures/images/logo.png", original_path

          # we use "filename" to get the correct extension here, it is more important
          # then any other param

          orig_size = File.size(original_path)

          OptimizedImage.resize(
            original_path,
            original_path,
            5,
            5,
            filename: "test.png"
          )

          new_size = File.size(original_path)
          expect(orig_size).to be > new_size
          expect(new_size).not_to eq(0)

        ensure
          File.delete(original_path) if File.exist?(original_path)
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
            File.delete(tmp_path) if File.exist?(tmp_path)
          end
        end
      end
    end

    describe '.downsize' do
      it 'should downsize logo (requires ImageMagick 7)' do
        tmp_path = "/tmp/downsized.png"

        begin
          OptimizedImage.downsize(
            "#{Rails.root}/spec/fixtures/images/logo.png",
            tmp_path,
            "100x100\>"
          )

          info = FastImage.new(tmp_path)
          expect(info.size).to eq([100, 27])
          expect(File.size(tmp_path)).to be < 2300

        ensure
          File.delete(tmp_path) if File.exist?(tmp_path)
        end
      end
    end
  end

  describe ".safe_path?" do

    it "correctly detects unsafe paths" do
      expect(OptimizedImage.safe_path?("/path/A-AA/22_00.JPG")).to eq(true)
      expect(OptimizedImage.safe_path?("/path/AAA/2200.JPG")).to eq(true)
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

    context "versioning" do
      let(:filename) { 'logo.png' }
      let(:file) { file_from_fixtures(filename) }

      it "is able to update optimized images on version change" do
        upload = UploadCreator.new(file, filename).create_for(Discourse.system_user.id)
        optimized = OptimizedImage.create_for(upload, 10, 10)

        expect(optimized.version).to eq(OptimizedImage::VERSION)

        optimized_again = OptimizedImage.create_for(upload, 10, 10)
        expect(optimized_again.id).to eq(optimized.id)

        optimized.update_columns(version: nil)
        old_id = optimized.id

        optimized_new = OptimizedImage.create_for(upload, 10, 10)

        expect(optimized_new.id).not_to eq(old_id)

        # cleanup (which transaction rollback may miss)
        optimized_new.destroy
        upload.destroy
      end
    end

    it "is able to 'optimize' an svg" do
      # we don't really optimize anything, we simply copy
      # but at least this confirms this actually works

      SiteSetting.authorized_extensions = 'svg'
      svg = file_from_fixtures('image.svg')
      upload = UploadCreator.new(svg, 'image.svg').create_for(Discourse.system_user.id)
      resized = upload.get_optimized_image(50, 50, {})

      # we perform some basic svg mangling but expect the string Discourse to be there
      expect(File.read(Discourse.store.path_for(resized))).to include("Discourse")
      expect(File.read(Discourse.store.path_for(resized))).to eq(File.read(Discourse.store.path_for(upload)))
    end

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

        it "is able to change the format" do
          oi = OptimizedImage.create_for(upload, 100, 200, format: 'gif')
          expect(oi.url).to eq("/internally/stored/optimized/image.gif")
        end

      end

    end

    describe "external store" do
      before do
        setup_s3
      end

      context "when we have a bad file returned" do
        it "returns nil" do
          s3_upload = Fabricate(:upload_s3)
          stub_request(:head, "http://#{s3_upload.url}").to_return(status: 200)
          stub_request(:get, "http://#{s3_upload.url}").to_return(status: 200)

          expect(OptimizedImage.create_for(s3_upload, 100, 200)).to eq(nil)
        end
      end

      context "when the thumbnail is properly generated" do
        context "secure media disabled" do
          let(:s3_upload) { Fabricate(:upload_s3) }
          let(:optimized_path) { %r{/optimized/\d+X.*/#{s3_upload.sha1}_2_100x200\.png} }

          before do
            stub_request(:head, "http://#{s3_upload.url}").to_return(status: 200)
            stub_request(:get, "http://#{s3_upload.url}").to_return(status: 200, body: file_from_fixtures("logo.png"))
            stub_request(:put, %r{https://#{SiteSetting.s3_upload_bucket}\.s3\.#{SiteSetting.s3_region}\.amazonaws.com#{optimized_path}})
              .to_return(status: 200, headers: { "ETag" => "someetag" })
          end

          it "downloads a copy of the original image" do
            oi = OptimizedImage.create_for(s3_upload, 100, 200)

            expect(oi.sha1).to_not be_nil
            expect(oi.extension).to eq(".png")
            expect(oi.width).to eq(100)
            expect(oi.height).to eq(200)
            expect(oi.url).to match(%r{//#{SiteSetting.s3_upload_bucket}\.s3\.dualstack\.us-west-1\.amazonaws\.com#{optimized_path}})
            expect(oi.filesize).to be > 0

            oi.filesize = nil

            stub_request(
              :get,
              %r{http://#{SiteSetting.s3_upload_bucket}\.s3\.dualstack\.us-west-1\.amazonaws\.com#{optimized_path}},
            ).to_return(status: 200, body: file_from_fixtures("resized.png"))

            expect(oi.filesize).to be > 0
          end
        end
      end
    end
  end

  describe '#destroy' do
    describe 'when upload_id is no longer valid' do
      it 'should still destroy the record' do
        image = Fabricate(:optimized_image)
        image.upload.delete
        image.reload.destroy

        expect(OptimizedImage.exists?(id: image.id)).to eq(false)
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

  def store_optimized_image(file, optimized_image, content_type = nil, secure: false)
    "/internally/stored/optimized/image#{optimized_image.extension}"
  end

end
