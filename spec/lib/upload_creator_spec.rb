# frozen_string_literal: true

require 'rails_helper'
require 'file_store/s3_store'

RSpec.describe UploadCreator do
  fab!(:user) { Fabricate(:user) }

  describe '#create_for' do
    describe 'when upload is not an image' do
      before do
        SiteSetting.authorized_extensions = 'txt|long-FileExtension'
      end

      let(:filename) { "utf-8.txt" }
      let(:file) { file_from_fixtures(filename, "encodings") }

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, "utf-8\n.txt").create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('txt')
        expect(File.extname(upload.url)).to eq('.txt')
        expect(upload.original_filename).to eq('utf-8.txt')
        expect(user.user_uploads.count).to eq(1)
        expect(upload.user_uploads.count).to eq(1)

        user2 = Fabricate(:user)

        expect do
          UploadCreator.new(file, "utf-8\n.txt").create_for(user2.id)
        end.to change { Upload.count }.by(0)

        expect(user.user_uploads.count).to eq(1)
        expect(user2.user_uploads.count).to eq(1)
        expect(upload.user_uploads.count).to eq(2)
      end

      let(:longextension) { "fake.long-FileExtension" }
      let(:file2) { file_from_fixtures(longextension) }

      it 'should truncate long extension names' do
        expect do
          UploadCreator.new(file2, "fake.long-FileExtension").create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('long-FileE')
      end
    end

    describe 'when image is not authorized' do
      describe 'when image is for site setting' do
        let(:filename) { 'logo.png' }
        let(:file) { file_from_fixtures(filename) }

        before do
          SiteSetting.authorized_extensions = 'jpg'
        end

        it 'should create the right upload' do
          upload = UploadCreator.new(file, filename,
            for_site_setting: true
          ).create_for(Discourse.system_user.id)

          expect(upload.persisted?).to eq(true)
          expect(upload.original_filename).to eq(filename)
        end
      end
    end

    describe 'when image has the wrong extension' do
      let(:filename) { "png_as.bin" }
      let(:file) { file_from_fixtures(filename) }

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, filename,
            force_optimize: true,
            type: UploadCreator::TYPES_TO_CROP.first
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('png')
        expect(File.extname(upload.url)).to eq('.png')
        expect(upload.original_filename).to eq('png_as.png')
      end

      describe 'for tiff format' do
        before do
          SiteSetting.authorized_extensions = '.tiff|.bin'
        end

        let(:filename) { "tiff_as.bin" }
        let(:file) { file_from_fixtures(filename) }

        it 'should not correct the coerce filename' do
          expect do
            UploadCreator.new(file, filename).create_for(user.id)
          end.to change { Upload.count }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq('bin')
          expect(File.extname(upload.url)).to eq('.bin')
          expect(upload.original_filename).to eq('tiff_as.bin')
        end
      end
    end

    context "when image is too big" do
      let(:filename) { 'logo.png' }
      let(:file) { file_from_fixtures(filename) }

      it "adds an error to the upload" do
        SiteSetting.max_image_size_kb = 1
        upload = UploadCreator.new(
          file, filename, force_optimize: true
        ).create_for(Discourse.system_user.id)
        expect(upload.errors.full_messages.first).to eq(
          "#{I18n.t("upload.images.too_large_humanized", max_size: "1 KB")}"
        )
      end
    end

    describe 'pngquant' do
      let(:filename) { "pngquant.png" }
      let(:file) { file_from_fixtures(filename) }

      it 'should apply pngquant to optimized images' do
        upload = UploadCreator.new(file, filename,
          pasted: true,
          force_optimize: true
        ).create_for(user.id)

        # no optimisation possible without losing details
        expect(upload.filesize).to eq(9558)

        thumbnail_size = upload.get_optimized_image(upload.width, upload.height, {}).filesize

        # pngquant will lose some colors causing some extra size reduction
        expect(thumbnail_size).to be < 7500
      end
    end

    describe 'converting to jpeg' do
      def image_quality(path)
        local_path = File.join(Rails.root, 'public', path)
        Discourse::Utils.execute_command("identify", "-format", "%Q", local_path).to_i
      end

      let(:filename) { "should_be_jpeg.png" }
      let(:file) { file_from_fixtures(filename) }

      let(:small_filename) { "logo.png" }
      let(:small_file) { file_from_fixtures(small_filename) }

      let(:large_filename) { "large_and_unoptimized.png" }
      let(:large_file) { file_from_fixtures(large_filename) }

      let(:animated_filename) { "animated.gif" }
      let(:animated_file) { file_from_fixtures(animated_filename) }

      let(:animated_webp_filename) { "animated.webp" }
      let(:animated_webp_file) { file_from_fixtures(animated_webp_filename) }

      before do
        SiteSetting.png_to_jpg_quality = 1
      end

      it 'should not store file as jpeg if it does not meet absolute byte saving requirements' do
        # logo.png is 2297 bytes, converting to jpeg saves 30% but does not meet
        # the absolute savings required of 25_000 bytes, if you save less than that
        # skip this

        expect do
          UploadCreator.new(small_file, small_filename,
            pasted: true,
            force_optimize: true
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('png')
        expect(File.extname(upload.url)).to eq('.png')
        expect(upload.original_filename).to eq('logo.png')
      end

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, filename,
            pasted: true,
            force_optimize: true
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('jpeg')
        expect(File.extname(upload.url)).to eq('.jpeg')
        expect(upload.original_filename).to eq('should_be_jpeg.jpg')
      end

      it "should not convert to jpeg when the image is uploaded from site setting" do
        upload = UploadCreator.new(large_file, large_filename, for_site_setting: true, force_optimize: true).create_for(user.id)

        expect(upload.extension).to eq('png')
        expect(File.extname(upload.url)).to eq('.png')
        expect(upload.original_filename).to eq('large_and_unoptimized.png')
      end

      context "jpeg image quality settings" do
        before do
          SiteSetting.png_to_jpg_quality = 75
          SiteSetting.recompress_original_jpg_quality = 40
          SiteSetting.image_preview_jpg_quality = 10
        end

        it 'should alter the image quality' do
          upload = UploadCreator.new(file, filename, force_optimize: true).create_for(user.id)

          expect(image_quality(upload.url)).to eq(SiteSetting.recompress_original_jpg_quality)

          upload.create_thumbnail!(100, 100)
          upload.reload

          expect(image_quality(upload.optimized_images.first.url)).to eq(SiteSetting.image_preview_jpg_quality)
        end

        it 'should not convert animated images' do
          expect do
            UploadCreator.new(animated_file, animated_filename,
              force_optimize: true
            ).create_for(user.id)
          end.to change { Upload.count }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq('gif')
          expect(File.extname(upload.url)).to eq('.gif')
          expect(upload.original_filename).to eq('animated.gif')
        end

        context "png image quality settings" do
          before do
            SiteSetting.png_to_jpg_quality = 100
            SiteSetting.recompress_original_jpg_quality = 90
            SiteSetting.image_preview_jpg_quality = 10
          end

          it "should not convert to jpeg when png_to_jpg_quality is 100" do
            upload = UploadCreator.new(large_file, large_filename, force_optimize: true).create_for(user.id)

            expect(upload.extension).to eq('png')
            expect(File.extname(upload.url)).to eq('.png')
            expect(upload.original_filename).to eq('large_and_unoptimized.png')
          end
        end

        it 'should not convert animated WEBP images' do
          expect do
            UploadCreator.new(animated_webp_file, animated_webp_filename,
              force_optimize: true
            ).create_for(user.id)
          end.to change { Upload.count }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq('webp')
          expect(File.extname(upload.url)).to eq('.webp')
          expect(upload.original_filename).to eq('animated.webp')
        end
      end
    end

    describe 'converting HEIF to jpeg' do
      let(:filename) { "should_be_jpeg.heic" }
      let(:file) { file_from_fixtures(filename, "images") }

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, filename).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('jpeg')
        expect(File.extname(upload.url)).to eq('.jpeg')
        expect(upload.original_filename).to eq('should_be_jpeg.jpg')
      end
    end

    describe 'secure attachments' do
      let(:filename) { "small.pdf" }
      let(:file) { file_from_fixtures(filename, "pdf") }
      let(:opts) { { type: "composer" } }

      before do
        setup_s3
        stub_s3_store

        SiteSetting.secure_media = true
        SiteSetting.authorized_extensions = 'pdf|svg|jpg'
      end

      it 'should mark attachments as secure' do
        upload = UploadCreator.new(file, filename, opts).create_for(user.id)
        stored_upload = Upload.last

        expect(stored_upload.secure?).to eq(true)
      end

      it 'should not mark theme uploads as secure' do
        fname = "custom-theme-icon-sprite.svg"
        upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

        expect(upload.secure?).to eq(false)
      end
    end

    context 'uploading to s3' do
      let(:filename) { "should_be_jpeg.png" }
      let(:file) { file_from_fixtures(filename) }
      let(:pdf_filename) { "small.pdf" }
      let(:pdf_file) { file_from_fixtures(pdf_filename, "pdf") }
      let(:opts) { { type: "composer" } }

      before do
        setup_s3
        stub_s3_store
      end

      it 'should store the file and return etag' do
        expect {
          UploadCreator.new(file, filename).create_for(user.id)
        }.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.etag).to eq('ETag')
      end

      it 'should return signed URL for secure attachments in S3' do
        SiteSetting.authorized_extensions = 'pdf'
        SiteSetting.secure_media = true

        upload = UploadCreator.new(pdf_file, pdf_filename, opts).create_for(user.id)
        stored_upload = Upload.last
        signed_url = Discourse.store.url_for(stored_upload)

        expect(stored_upload.secure?).to eq(true)
        expect(stored_upload.url).not_to eq(signed_url)
        expect(signed_url).to match(/Amz-Credential/)
      end
    end

    context "when the upload already exists based on the sha1" do
      let(:filename) { "small.pdf" }
      let(:file) { file_from_fixtures(filename, "pdf") }
      let!(:existing_upload) { Fabricate(:upload, sha1: Upload.generate_digest(file)) }
      let(:result) { UploadCreator.new(file, filename).create_for(user.id) }

      it "returns the existing upload" do
        expect(result).to eq(existing_upload)
      end

      it "does not set an original_sha1 normally" do
        expect(result.original_sha1).to eq(nil)
      end

      it "creates a userupload record" do
        result
        expect(UserUpload.exists?(user_id: user.id, upload_id: existing_upload.id)).to eq(true)
      end

      context "when the existing upload URL is blank (it has failed)" do
        before do
          existing_upload.update(url: '')
        end

        it "destroys the existing upload" do
          result
          expect(Upload.find_by(id: existing_upload.id)).to eq(nil)
        end
      end

      context "when SiteSetting.secure_media is enabled" do
        before do
          setup_s3
          stub_s3_store

          SiteSetting.secure_media = true
        end

        it "does not return the existing upload, as duplicate uploads are allowed" do
          expect(result).not_to eq(existing_upload)
        end
      end
    end

    context "secure media functionality" do
      let(:filename) { "logo.jpg" }
      let(:file) { file_from_fixtures(filename) }
      let(:opts) { {} }
      let(:result) { UploadCreator.new(file, filename, opts).create_for(user.id) }

      context "when SiteSetting.secure_media enabled" do
        before do
          setup_s3
          stub_s3_store

          SiteSetting.secure_media = true
        end

        it "sets an original_sha1 on the upload created because the sha1 column is securerandom in this case" do
          expect(result.original_sha1).not_to eq(nil)
        end

        context "when uploading in a public context (theme, site setting, avatar, custom_emoji, profile_background, card_background)" do
          def expect_no_public_context_uploads_to_be_secure
            upload = UploadCreator.new(file_from_fixtures(filename), filename, for_site_setting: true).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload = UploadCreator.new(file_from_fixtures(filename), filename, for_gravatar: true).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload = UploadCreator.new(file_from_fixtures(filename), filename, for_theme: true).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload = UploadCreator.new(file_from_fixtures(filename), filename, type: "avatar").create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload = UploadCreator.new(file_from_fixtures(filename), filename, type: "custom_emoji").create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload = UploadCreator.new(file_from_fixtures(filename), filename, type: "profile_background").create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload = UploadCreator.new(file_from_fixtures(filename), filename, type: "card_background").create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!
          end

          it "does not set the upload to secure" do
            expect_no_public_context_uploads_to_be_secure
          end

          context "when login required" do
            before do
              SiteSetting.login_required = true
            end

            it "does not set the upload to secure" do
              expect_no_public_context_uploads_to_be_secure
            end
          end
        end

        context "if type of upload is in the composer" do
          let(:opts) { { type: "composer" } }
          it "sets the upload to secure and sets the original_sha1 column, because we don't know the context of the composer" do
            expect(result.secure).to eq(true)
            expect(result.original_sha1).not_to eq(nil)
          end
        end

        context "if the upload is for a PM" do
          let(:opts) { { for_private_message: true } }
          it "sets the upload to secure and sets the original_sha1" do
            expect(result.secure).to eq(true)
            expect(result.original_sha1).not_to eq(nil)
          end
        end

        context "if the upload is for a group message" do
          let(:opts) { { for_group_message: true } }
          it "sets the upload to secure and sets the original_sha1" do
            expect(result.secure).to eq(true)
            expect(result.original_sha1).not_to eq(nil)
          end
        end

        context "if SiteSetting.login_required" do
          before do
            SiteSetting.login_required = true
          end
          it "sets the upload to secure and sets the original_sha1" do
            expect(result.secure).to eq(true)
            expect(result.original_sha1).not_to eq(nil)
          end
        end
      end
    end

    context 'custom emojis' do
      let(:animated_filename) { "animated.gif" }
      let(:animated_file) { file_from_fixtures(animated_filename) }

      it 'should not be cropped if animated' do
        upload = UploadCreator.new(animated_file, animated_filename,
          force_optimize: true,
          type: 'custom_emoji'
        ).create_for(user.id)

        expect(upload.animated).to eq(true)
        expect(FastImage.size(Discourse.store.path_for(upload))).to eq([320, 320])
      end
    end

    describe 'skip validations' do
      let(:filename) { "small.pdf" }
      let(:file) { file_from_fixtures(filename, "pdf") }

      before do
        SiteSetting.authorized_extensions = 'png|jpg'
      end

      it 'creates upload when skip_validations is true' do
        upload = UploadCreator.new(file, filename,
          skip_validations: true
        ).create_for(user.id)

        expect(upload.persisted?).to eq(true)
        expect(upload.original_filename).to eq(filename)
      end

      it 'does not create upload when skip_validations is false' do
        upload = UploadCreator.new(file, filename,
          skip_validations: false
        ).create_for(user.id)

        expect(upload.persisted?).to eq(false)
      end
    end
  end

  describe '#convert_favicon_to_png!' do
    let(:filename) { "smallest.ico" }
    let(:file) { file_from_fixtures(filename, "images") }

    before do
      SiteSetting.authorized_extensions = 'png|jpg|ico'
    end

    it 'converts to png' do
      upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(upload.persisted?).to eq(true)
      expect(upload.extension).to eq('png')
    end

  end

  describe '#clean_svg!' do
    let(:b64) do
      Base64.encode64('<svg onmouseover="alert(alert)" />')
    end

    let(:file) do
      file = Tempfile.new
      file.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="200px" height="200px" onload="alert(location)">
          <defs>
            <path id="pathdef" d="m0 0h100v100h-77z" stroke="#000" />
          </defs>
          <g>
            <use id="valid-use" x="123" href="#pathdef" />
          </g>
          <use id="invalid-use1" href="https://svg.example.com/evil.svg" />
          <use id="invalid-use2" href="data:image/svg+xml;base64,#{b64}" />
        </svg>
      XML
      file.rewind
      file
    end

    it 'removes event handlers' do
      begin
        UploadCreator.new(file, 'file.svg').clean_svg!
        file_content = file.read
        expect(file_content).not_to include('onload')
        expect(file_content).to include('#pathdef')
        expect(file_content).not_to include('evil.svg')
        expect(file_content).not_to include(b64)
      ensure
        file.unlink
      end
    end
  end

  describe "svg sizes expressed in units other than pixels" do
    let(:tiny_svg_filename) { "tiny.svg" }
    let(:tiny_svg_file) { file_from_fixtures(tiny_svg_filename) }

    let(:massive_svg_filename) { "massive.svg" }
    let(:massive_svg_file) { file_from_fixtures(massive_svg_filename) }

    let(:zero_sized_svg_filename) { "zero_sized.svg" }
    let(:zero_sized_svg_file) { file_from_fixtures(zero_sized_svg_filename) }

    it "should be viewable when a dimension is a fraction of a unit" do
      upload = UploadCreator.new(tiny_svg_file, tiny_svg_filename,
        force_optimize: true,
      ).create_for(user.id)

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end

    it "should not be larger than the maximum thumbnail size" do
      upload = UploadCreator.new(massive_svg_file, massive_svg_filename,
        force_optimize: true,
      ).create_for(user.id)

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end

    it "should handle zero dimension files" do
      upload = UploadCreator.new(zero_sized_svg_file, zero_sized_svg_filename,
        force_optimize: true,
      ).create_for(user.id)

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end
  end

  describe '#should_downsize?' do
    context "GIF image" do
      let(:gif_file) { file_from_fixtures("animated.gif") }

      before do
        SiteSetting.max_image_size_kb = 1
      end

      it "is not downsized" do
        creator = UploadCreator.new(gif_file, "animated.gif")
        creator.extract_image_info!
        expect(creator.should_downsize?).to eq(false)
      end
    end
  end

  describe 'before_upload_creation event' do
    let(:filename) { "logo.jpg" }
    let(:file) { file_from_fixtures(filename) }

    before do
      setup_s3
      stub_s3_store
    end

    it 'does not save the upload if an event added errors to the upload' do
      error = 'This upload is invalid'

      event = Proc.new do |file, is_image, upload|
        upload.errors.add(:base, error)
      end

      DiscourseEvent.on(:before_upload_creation, &event)

      created_upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(created_upload.persisted?).to eq(false)
      expect(created_upload.errors).to contain_exactly(error)
      DiscourseEvent.off(:before_upload_creation, &event)
    end
  end
end
