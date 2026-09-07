# frozen_string_literal: true

require "file_store/s3_store"

RSpec.describe UploadCreator do
  fab!(:user)
  fab!(:admin)

  describe "#create_for" do
    context "when the upload is an SVG" do
      before { SiteSetting.authorized_extensions = "svg" }

      it "removes external use references while preserving local fragments" do
        xlink_namespace = "http://www.w3.org/1999/xlink"
        svg = <<~XML
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="#{xlink_namespace}" width="10" height="10">
        <defs><path id="mark" d="M0 0h10v10H0z" /></defs>
        <use id="local-href" href="#mark" />
        <use id="external-href" href="https://example.com/evil.svg#mark" />
        <use id="data-href" href="data:image/svg+xml,evil" />
        <use id="local-xlink-href" xlink:href="#mark" />
        <use id="external-xlink-href" xlink:href="https://example.com/evil.svg#mark" />
      </svg>
    XML

        upload =
          UploadCreator.new(file_from_contents(svg, "image.svg"), "image.svg").create_for(user.id)

        document = Nokogiri.XML(File.read(Discourse.store.path_for(upload)))

        expect(upload).to be_persisted
        expect(document.at_css("#local-href")["href"]).to eq("#mark")
        expect(document.at_css("#external-href")["href"]).to eq(nil)
        expect(document.at_css("#data-href")["href"]).to eq(nil)
        expect(
          document.at_css("#local-xlink-href").attribute_with_ns("href", xlink_namespace)&.value,
        ).to eq("#mark")
        expect(
          document.at_css("#external-xlink-href").attribute_with_ns("href", xlink_namespace)&.value,
        ).to eq(nil)
      end

      it "stores an SVG upload without event handlers" do
        file = Tempfile.new
        file.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <svg xmlns="http://www.w3.org/2000/svg" onload="alert(location)"></svg>
        XML
        file.rewind

        upload = UploadCreator.new(file, "file.svg").create_for(user.id)
        file_content = File.read(Discourse.store.path_for(upload))
        document = Nokogiri.XML(file_content)

        expect(upload).to be_persisted
        expect(document.xpath("//@*[starts-with(name(), 'on')]")).to be_empty
      ensure
        file&.close!
      end

      it "removes entity references and subsets from a hostile SVG upload" do
        upload =
          UploadCreator.new(
            file_from_fixtures("hostile_entity.svg"),
            "hostile_entity.svg",
          ).create_for(user.id)
        file_content = File.read(Discourse.store.path_for(upload))
        document = Nokogiri.XML(file_content)

        expect(upload).to be_persisted
        expect(document.internal_subset).to eq(nil)
        expect(document.external_subset).to eq(nil)
        expect(document.xpath("//text()").map(&:text).join).not_to include("root:")
        expect(file_content).not_to include("file:///etc/passwd")
      end
    end

    context "when the PNG contains transparency" do
      let(:filename) { "transparent.png" }
      let(:file) { file_from_fixtures(filename) }

      it "preserves the transparent pixel in the stored image" do
        upload = described_class.new(file, filename).create_for(user.id)
        stored_path = Discourse.store.path_for(upload)
        stored_image = ChunkyPNG::Image.from_file(stored_path)

        expect(upload).to be_persisted
        expect(upload.extension).to eq("png")
        expect(FastImage.type(stored_path)).to eq(:png)
        expect(FastImage.size(stored_path)).to eq([1, 1])
        expect(ChunkyPNG::Color.a(stored_image[0, 0])).to eq(127)
      end
    end

    describe "when upload is not an image" do
      before { SiteSetting.authorized_extensions = "txt|long-FileExtension" }

      let(:filename) { "utf-8.txt" }
      let(:file) { file_from_fixtures(filename, "encodings") }

      it "should store the upload with the right extension" do
        expect do UploadCreator.new(file, "utf-8\n.txt").create_for(user.id) end.to change {
          Upload.count
        }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq("txt")
        expect(File.extname(upload.url)).to eq(".txt")
        expect(upload.original_filename).to eq("utf-8.txt")
        expect(user.user_uploads.count).to eq(1)
        expect(upload.user_uploads.count).to eq(1)

        user2 = Fabricate(:user)

        expect do UploadCreator.new(file, "utf-8\n.txt").create_for(user2.id) end.not_to change {
          Upload.count
        }

        expect(user.user_uploads.count).to eq(1)
        expect(user2.user_uploads.count).to eq(1)
        expect(upload.user_uploads.count).to eq(2)
      end

      let(:longextension) { "fake.long-FileExtension" }
      let(:file2) { file_from_fixtures(longextension) }

      it "should truncate long extension names" do
        expect do
          UploadCreator.new(file2, "fake.long-FileExtension").create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq("long-FileE")
      end
    end

    describe "when image is not authorized" do
      describe "when image is for site setting" do
        let(:filename) { "logo.png" }
        let(:file) { file_from_fixtures(filename) }

        before { SiteSetting.authorized_extensions = "jpg" }

        it "should create the right upload" do
          upload =
            UploadCreator.new(file, filename, for_site_setting: true).create_for(
              Discourse.system_user.id,
            )

          expect(upload.persisted?).to eq(true)
          expect(upload.original_filename).to eq(filename)
        end
      end
    end

    describe "when image has the wrong extension" do
      let(:filename) { "png_as.bin" }
      let(:file) { file_from_fixtures(filename) }

      it "detects and stores PNG content with a .bin extension" do
        upload = UploadCreator.new(file, filename).create_for(user.id)
        stored_path = Discourse.store.path_for(upload)

        expect(upload).to be_persisted
        expect(upload).to have_attributes(
          original_filename: "png_as.png",
          extension: "png",
          width: 5,
          height: 1,
        )
        expect(FastImage.type(stored_path)).to eq(:png)
        expect(FastImage.size(stored_path)).to eq([5, 1])
      end

      describe "for tiff format" do
        before { SiteSetting.authorized_extensions = ".tiff|.bin" }

        let(:filename) { "tiff_as.bin" }
        let(:file) { file_from_fixtures(filename) }

        it "should not correct the coerce filename" do
          expect do UploadCreator.new(file, filename).create_for(user.id) end.to change {
            Upload.count
          }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq("bin")
          expect(File.extname(upload.url)).to eq(".bin")
          expect(upload.original_filename).to eq("tiff_as.bin")
        end
      end
    end

    context "when image is too big" do
      let(:filename) { "logo.png" }
      let(:file) { file_from_fixtures(filename) }

      it "adds an error to the upload" do
        SiteSetting.max_image_size_kb = 1
        upload =
          UploadCreator.new(file, filename, force_optimize: true).create_for(
            Discourse.system_user.id,
          )
        expect(upload.errors.full_messages.first).to eq(
          "#{I18n.t("upload.images.too_large_humanized", max_size: "1 KB")}",
        )
      end
    end

    context "when optimization is forced for an animated GIF" do
      let(:file) do
        # Regenerate from the repository root with:
        # ruby -rbase64 -e 'File.binwrite("spec/fixtures/images/tiny_animated.gif", Base64.strict_decode64("R0lGODlhAgABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQAAAAAACwAAAAAAgABAAACAgQKACH5BAAKAAAALAAAAAACAAEAgAAA/wAAAAICBAoAOw=="))'
        file_from_fixtures("tiny_animated.gif")
      end

      it "preserves the GIF and records its animation metadata" do
        upload =
          described_class.new(file, "tiny_animated.gif", force_optimize: true).create_for(user.id)
        stored_path = Discourse.store.path_for(upload)

        expect(upload).to be_persisted
        expect(upload.extension).to eq("gif")
        expect(upload.width).to eq(2)
        expect(upload.height).to eq(1)
        expect(upload.animated).to eq(true)
        expect(FastImage.type(stored_path)).to eq(:gif)
        expect(FastImage.size(stored_path)).to eq([2, 1])
      end
    end

    context "when a JPEG has EXIF orientation metadata" do
      include ImageOrientationHelpers

      # Regenerate from the repository root:
      # magick \( xc:red xc:lime xc:blue +append \) \( xc:cyan xc:magenta xc:yellow +append \) -append -scale 60x40! -sampling-factor 4:4:4 -quality 95 spec/fixtures/images/exif_orientation.jpg
      let(:source_path) { Rails.root.join("spec/fixtures/images/exif_orientation.jpg") }
      let(:expected_color_grids) do
        {
          1 => [%i[red green blue], %i[cyan magenta yellow]],
          2 => [%i[blue green red], %i[yellow magenta cyan]],
          3 => [%i[yellow magenta cyan], %i[blue green red]],
          4 => [%i[cyan magenta yellow], %i[red green blue]],
          5 => [%i[red cyan], %i[green magenta], %i[blue yellow]],
          6 => [%i[cyan red], %i[magenta green], %i[yellow blue]],
          7 => [%i[yellow blue], %i[magenta green], %i[cyan red]],
          8 => [%i[blue yellow], %i[green magenta], %i[red cyan]],
        }
      end
      let(:palette) do
        {
          red: [255, 0, 0],
          green: [0, 255, 0],
          blue: [0, 0, 255],
          cyan: [0, 255, 255],
          magenta: [255, 0, 255],
          yellow: [255, 255, 0],
        }
      end

      it "honors every EXIF orientation when storing JPEG uploads" do
        expected_color_grids.each do |orientation, expected_color_grid|
          with_jpeg_orientation(
            source_path: source_path,
            orientation: orientation,
          ) do |oriented_file|
            upload =
              described_class.new(
                oriented_file,
                "oriented-#{orientation}.jpg",
                force_optimize: true,
              ).create_for(user.id)
            actual_color_grid =
              stored_color_grid(
                upload: upload,
                rows: expected_color_grid.length,
                columns: expected_color_grid.first.length,
                palette: palette,
              )

            expect(upload).to be_persisted
            expect(upload).to have_attributes(
              width: expected_color_grid.first.length * 20,
              height: expected_color_grid.length * 20,
            )
            expect(actual_color_grid).to eq(expected_color_grid)
          end
        end
      end
    end

    context "when a detected PNG cannot be decoded during conversion" do
      # Regenerate from the repository root with:
      # ruby -rzlib -e 'ihdr = [1, 1, 8, 6, 0, 0, 0].pack("NNCCCCC"); chunk = [ihdr.bytesize].pack("N") + "IHDR" + ihdr + [Zlib.crc32("IHDR" + ihdr)].pack("N"); File.binwrite("spec/fixtures/images/broken.png", "\x89PNG\r\n\x1A\n".b + chunk + ("\0".b * 80_000))'
      let(:broken_png_file) { file_from_fixtures("broken.png") }

      it "does not persist the upload" do
        SiteSetting.png_to_jpg_quality = 1

        expect do
          expect do
            UploadCreator.new(
              broken_png_file,
              "broken.png",
              pasted: true,
              force_optimize: true,
            ).create_for(user.id)
          end.to raise_error(Discourse::Utils::CommandError)
        end.not_to change(Upload, :count)
      end
    end

    describe "pngquant" do
      let(:filename) { "pngquant.png" }
      let(:file) { file_from_fixtures(filename) }

      it "should apply pngquant to optimized images" do
        upload =
          UploadCreator.new(file, filename, pasted: true, force_optimize: true).create_for(user.id)

        # no optimisation possible without losing details
        expect(upload.filesize).to be_between(1000, 9210)

        thumbnail_size = upload.get_optimized_image(upload.width, upload.height, {}).filesize

        # pngquant will lose some colors causing some extra size reduction
        expect(thumbnail_size).to be_between(1000, 7500)
      end
    end

    describe "converting to jpeg" do
      def image_quality(path)
        local_path = File.join(Rails.root, "public", path)
        Discourse::Utils.execute_command("identify", "-ping", "-format", "%Q", local_path).to_i
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

      before { SiteSetting.png_to_jpg_quality = 1 }

      it "should not store file as jpeg if it does not meet absolute byte saving requirements" do
        # logo.png is 2297 bytes, converting to jpeg saves 30% but does not meet
        # the absolute savings required of 25_000 bytes, if you save less than that
        # skip this

        expect do
          UploadCreator.new(
            small_file,
            small_filename,
            pasted: true,
            force_optimize: true,
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq("png")
        expect(File.extname(upload.url)).to eq(".png")
        expect(upload.original_filename).to eq("logo.png")
      end

      it "should store the upload with the right extension" do
        expect do
          UploadCreator.new(file, filename, pasted: true, force_optimize: true).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq("jpeg")
        expect(File.extname(upload.url)).to eq(".jpeg")
        expect(upload.original_filename).to eq("should_be_jpeg.jpg")
        expect(FastImage.type(Discourse.store.path_for(upload))).to eq(:jpeg)
        expect(FastImage.size(Discourse.store.path_for(upload))).to eq([303, 231])
      end

      it "should not convert to jpeg when the image is uploaded from site setting" do
        upload =
          UploadCreator.new(
            large_file,
            large_filename,
            for_site_setting: true,
            force_optimize: true,
          ).create_for(admin.id)

        expect(upload.extension).to eq("png")
        expect(File.extname(upload.url)).to eq(".png")
        expect(upload.original_filename).to eq("large_and_unoptimized.png")
      end

      it "should not convert to jpeg for admin asset upload types" do
        upload =
          UploadCreator.new(
            large_file,
            large_filename,
            type: "branding",
            force_optimize: true,
          ).create_for(admin.id)

        expect(upload.extension).to eq("png")
        expect(File.extname(upload.url)).to eq(".png")
        expect(upload.original_filename).to eq("large_and_unoptimized.png")
      end

      context "with jpeg image quality settings" do
        before do
          SiteSetting.png_to_jpg_quality = 75
          SiteSetting.recompress_original_jpg_quality = 40
          SiteSetting.image_preview_jpg_quality = 10
        end

        it "should alter the image quality" do
          upload = UploadCreator.new(file, filename, force_optimize: true).create_for(user.id)

          expect(image_quality(upload.url)).to eq(SiteSetting.recompress_original_jpg_quality)

          upload.create_thumbnail!(100, 100)
          upload.reload

          expect(image_quality(upload.optimized_images.first.url)).to eq(
            SiteSetting.image_preview_jpg_quality,
          )
        end

        it "should not convert animated images" do
          expect do
            UploadCreator.new(animated_file, animated_filename, force_optimize: true).create_for(
              user.id,
            )
          end.to change { Upload.count }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq("gif")
          expect(File.extname(upload.url)).to eq(".gif")
          expect(upload.original_filename).to eq("animated.gif")
        end

        context "with png image quality settings" do
          before do
            SiteSetting.png_to_jpg_quality = 100
            SiteSetting.recompress_original_jpg_quality = 90
            SiteSetting.image_preview_jpg_quality = 10
          end

          it "should not convert to jpeg when png_to_jpg_quality is 100" do
            upload =
              UploadCreator.new(large_file, large_filename, force_optimize: true).create_for(
                user.id,
              )

            expect(upload.extension).to eq("png")
            expect(File.extname(upload.url)).to eq(".png")
            expect(upload.original_filename).to eq("large_and_unoptimized.png")
          end

          it "should not convert pasted images to jpeg when png_to_jpg_quality is 100" do
            upload =
              UploadCreator.new(
                large_file,
                large_filename,
                pasted: true,
                force_optimize: true,
              ).create_for(user.id)

            expect(upload.extension).to eq("png")
            expect(File.extname(upload.url)).to eq(".png")
            expect(upload.original_filename).to eq("large_and_unoptimized.png")
          end
        end

        it "should not convert animated WEBP images" do
          expect do
            UploadCreator.new(
              animated_webp_file,
              animated_webp_filename,
              force_optimize: true,
            ).create_for(user.id)
          end.to change { Upload.count }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq("webp")
          expect(File.extname(upload.url)).to eq(".webp")
          expect(upload.original_filename).to eq("animated.webp")
        end
      end
    end

    describe "converting HEIF to jpeg" do
      let(:filename) { "should_be_jpeg.heic" }
      let(:file) { file_from_fixtures(filename, "images") }

      it "should store the upload with the right extension" do
        expect do
          UploadCreator.new(file, filename, force_optimize: true).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq("jpeg")
        expect(File.extname(upload.url)).to eq(".jpeg")
        expect(upload.original_filename).to eq("should_be_jpeg.jpg")
      end
    end

    describe "secure attachments" do
      let(:filename) { "small.pdf" }
      let(:file) { file_from_fixtures(filename, "pdf") }
      let(:opts) { { type: "composer" } }

      before do
        setup_s3
        stub_s3_store

        SiteSetting.secure_uploads = true
        SiteSetting.authorized_extensions = "pdf|svg|jpg"
      end

      it "should mark attachments as secure" do
        upload = UploadCreator.new(file, filename, opts).create_for(user.id)
        stored_upload = Upload.last

        expect(stored_upload.secure?).to eq(true)
      end

      it "should not mark theme uploads as secure" do
        fname = "custom-theme-icon-sprite.svg"
        upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

        expect(upload.secure?).to eq(false)
      end

      it "sets a reason for the security" do
        upload = UploadCreator.new(file, filename, opts).create_for(user.id)
        stored_upload = Upload.last

        expect(stored_upload.secure?).to eq(true)
        expect(stored_upload.security_last_changed_at).not_to eq(nil)
        expect(stored_upload.security_last_changed_reason).to eq(
          "uploading via the composer | source: upload creator",
        )
      end
    end

    context "when uploading to s3" do
      let(:filename) { "should_be_jpeg.png" }
      let(:file) { file_from_fixtures(filename) }
      let(:pdf_filename) { "small.pdf" }
      let(:pdf_file) { file_from_fixtures(pdf_filename, "pdf") }
      let(:opts) { { type: "composer" } }

      before do
        setup_s3
        stub_s3_store
      end

      it "should store the file and return etag" do
        expect { UploadCreator.new(file, filename).create_for(user.id) }.to change {
          Upload.count
        }.by(1)

        upload = Upload.last

        expect(upload.etag).to eq("ETag")
      end

      it "should return signed URL for secure attachments in S3" do
        SiteSetting.authorized_extensions = "pdf"
        SiteSetting.secure_uploads = true

        upload = UploadCreator.new(pdf_file, pdf_filename, opts).create_for(user.id)
        stored_upload = Upload.last
        signed_url = Discourse.store.url_for(stored_upload)

        expect(stored_upload.secure?).to eq(true)
        expect(stored_upload.url).not_to eq(signed_url)
        expect(signed_url).to match(/Amz-Credential/)
      end

      it "should return CDN URL when enabled" do
        SiteSetting.s3_use_cdn_url_for_all_uploads = true
        SiteSetting.authorized_extensions = "pdf"
        SiteSetting.s3_cdn_url = "https://example-cdn.com"

        upload = UploadCreator.new(pdf_file, pdf_filename, opts).create_for(user.id)
        stored_upload = Upload.last
        cdn_url = Discourse.store.url_for(stored_upload)

        expect(cdn_url).to match(/example-cdn\.com/)
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
        before { existing_upload.update(url: "") }

        it "destroys the existing upload" do
          result
          expect(Upload.find_by(id: existing_upload.id)).to eq(nil)
        end
      end

      context "when SiteSetting.secure_uploads is enabled" do
        before do
          setup_s3
          stub_s3_store

          SiteSetting.secure_uploads = true
        end

        it "does not return the existing upload, as duplicate uploads are allowed" do
          expect(result).not_to eq(existing_upload)
        end
      end
    end

    context "when the video thumbnail already exists based on the sha1" do
      let(:filename) { "smallest.png" }
      let(:file) { file_from_fixtures(filename, "images") }
      let!(:existing_upload) { Fabricate(:upload, sha1: Upload.generate_digest(file)) }
      let(:opts) { { type: "thumbnail" } }
      let(:result) { UploadCreator.new(file, filename, opts).create_for(user.id) }

      it "does not return the existing upload, as duplicate uploads are allowed" do
        expect(result).not_to eq(existing_upload)
      end
    end

    context "with secure uploads functionality" do
      let(:filename) { "logo.jpg" }
      let(:file) { file_from_fixtures(filename) }
      let(:opts) { {} }
      let(:result) { UploadCreator.new(file, filename, opts).create_for(user.id) }

      context "when SiteSetting.secure_uploads enabled" do
        before do
          setup_s3
          stub_s3_store

          SiteSetting.secure_uploads = true
        end

        it "sets an original_sha1 on the upload created because the sha1 column is securerandom in this case" do
          expect(result.original_sha1).not_to eq(nil)
        end

        context "when uploading in a public context (theme, site setting, avatar, custom_emoji, profile_background, card_background)" do
          def expect_no_public_context_uploads_to_be_secure
            upload =
              UploadCreator.new(
                file_from_fixtures(filename),
                filename,
                for_site_setting: true,
              ).create_for(admin.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload =
              UploadCreator.new(
                file_from_fixtures(filename),
                filename,
                for_gravatar: true,
              ).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload =
              UploadCreator.new(file_from_fixtures(filename), filename, for_theme: true).create_for(
                user.id,
              )
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload =
              UploadCreator.new(file_from_fixtures(filename), filename, type: "avatar").create_for(
                user.id,
              )
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload =
              UploadCreator.new(
                file_from_fixtures(filename),
                filename,
                type: "custom_emoji",
              ).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload =
              UploadCreator.new(
                file_from_fixtures(filename),
                filename,
                type: "profile_background",
              ).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!

            upload =
              UploadCreator.new(
                file_from_fixtures(filename),
                filename,
                type: "card_background",
              ).create_for(user.id)
            expect(upload.secure).to eq(false)
            upload.destroy!
          end

          it "does not set the upload to secure" do
            expect_no_public_context_uploads_to_be_secure
          end

          context "when login required" do
            before { SiteSetting.login_required = true }

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
          before { SiteSetting.login_required = true }
          it "sets the upload to secure and sets the original_sha1" do
            expect(result.secure).to eq(true)
            expect(result.original_sha1).not_to eq(nil)
          end
        end

        context "with primary upload deduplication" do
          let(:opts) { { for_private_message: true } }

          it "deduplicates when a primary exists with same original_sha1 and secure status" do
            # Create first upload which becomes the primary
            first_upload = UploadCreator.new(file, filename, opts).create_for(user.id)
            expect(first_upload.primary_upload_id).to be_nil
            expect(first_upload.original_sha1).to be_present
            primary_url = first_upload.url

            # Create second upload with same file - should reference the primary
            second_upload =
              UploadCreator.new(file_from_fixtures(filename), filename, opts).create_for(user.id)

            expect(second_upload.id).not_to eq(first_upload.id)
            expect(second_upload.primary_upload_id).to eq(first_upload.id)
            expect(second_upload.url).to eq(primary_url)
            expect(second_upload.original_sha1).to eq(first_upload.original_sha1)
          end

          it "creates separate primaries for different security contexts" do
            # Create secure upload
            secure_upload = UploadCreator.new(file, filename, opts).create_for(user.id)
            expect(secure_upload.secure).to eq(true)
            expect(secure_upload.primary_upload_id).to be_nil

            # Create public upload with same file
            public_opts = { for_site_setting: true }
            public_upload =
              UploadCreator.new(file_from_fixtures(filename), filename, public_opts).create_for(
                admin.id,
              )

            expect(public_upload.secure).to eq(false)
            expect(public_upload.primary_upload_id).to be_nil
            expect(public_upload.original_sha1).to eq(secure_upload.original_sha1)
            expect(public_upload.url).not_to eq(secure_upload.url)
          end

          it "does not deduplicate thumbnails" do
            thumb_opts = opts.merge(type: "thumbnail")

            first_thumb = UploadCreator.new(file, filename, thumb_opts).create_for(user.id)
            second_thumb =
              UploadCreator.new(file_from_fixtures(filename), filename, thumb_opts).create_for(
                user.id,
              )

            expect(first_thumb.primary_upload_id).to be_nil
            expect(second_thumb.primary_upload_id).to be_nil
          end

          it "does not use a thumbnail as the primary for a regular upload" do
            thumb_opts = opts.merge(type: "thumbnail")
            thumbnail = UploadCreator.new(file, filename, thumb_opts).create_for(user.id)
            regular_upload =
              UploadCreator.new(file_from_fixtures(filename), filename, opts).create_for(user.id)

            expect(thumbnail.primary_upload_id).to be_nil
            expect(thumbnail.original_sha1).to be_nil
            expect(regular_upload.primary_upload_id).to be_nil
            expect(regular_upload.url).not_to eq(thumbnail.url)
          end
        end
      end
    end

    context "with custom emojis" do
      let(:animated_filename) { "animated.gif" }
      let(:animated_file) { file_from_fixtures(animated_filename) }

      it "should not be cropped if animated" do
        upload =
          UploadCreator.new(
            animated_file,
            animated_filename,
            force_optimize: true,
            type: "custom_emoji",
          ).create_for(user.id)

        expect(upload.animated).to eq(true)
        expect(FastImage.size(Discourse.store.path_for(upload))).to eq([320, 320])
      end
    end

    describe "skip validations" do
      let(:filename) { "small.pdf" }
      let(:file) { file_from_fixtures(filename, "pdf") }

      before { SiteSetting.authorized_extensions = "png|jpg" }

      it "creates upload when skip_validations is true" do
        upload = UploadCreator.new(file, filename, skip_validations: true).create_for(user.id)

        expect(upload.persisted?).to eq(true)
        expect(upload.original_filename).to eq(filename)
      end

      it "does not create upload when skip_validations is false" do
        upload = UploadCreator.new(file, filename, skip_validations: false).create_for(user.id)

        expect(upload.persisted?).to eq(false)
      end
    end

    context "when the upload is an ICO favicon" do
      let(:filename) { "smallest.ico" }
      let(:file) { file_from_fixtures(filename, "images") }

      before { SiteSetting.authorized_extensions = "png|jpg|ico" }

      it "stores it as a PNG" do
        upload = described_class.new(file, filename).create_for(user.id)
        stored_path = Discourse.store.path_for(upload)

        expect(upload).to be_persisted
        expect(upload.extension).to eq("png")
        expect(upload.original_filename).to eq("smallest.png")
        expect(FastImage.type(stored_path)).to eq(:png)
        expect(FastImage.size(stored_path)).to eq([1, 1])
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
      upload =
        UploadCreator.new(tiny_svg_file, tiny_svg_filename, force_optimize: true).create_for(
          user.id,
        )

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end

    it "should not be larger than the maximum thumbnail size" do
      upload =
        UploadCreator.new(massive_svg_file, massive_svg_filename, force_optimize: true).create_for(
          user.id,
        )

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end

    it "should handle zero dimension files" do
      upload =
        UploadCreator.new(
          zero_sized_svg_file,
          zero_sized_svg_filename,
          force_optimize: true,
        ).create_for(user.id)

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end
  end

  describe "#should_downsize?" do
    context "with GIF image" do
      let(:gif_file) { file_from_fixtures("animated.gif") }

      before { SiteSetting.max_image_size_kb = 1 }

      it "is not downsized" do
        creator = UploadCreator.new(gif_file, "animated.gif")
        creator.extract_image_info!
        expect(creator.should_downsize?).to eq(false)
      end
    end
  end

  describe "before_upload_creation event" do
    let(:filename) { "logo.jpg" }
    let(:file) { file_from_fixtures(filename) }

    before do
      setup_s3
      stub_s3_store
    end

    it "does not save the upload if an event added errors to the upload" do
      error = "This upload is invalid"

      event = Proc.new { |file, is_image, upload| upload.errors.add(:base, error) }

      DiscourseEvent.on(:before_upload_creation, &event)

      created_upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(created_upload.persisted?).to eq(false)
      expect(created_upload.errors).to contain_exactly(error)
      DiscourseEvent.off(:before_upload_creation, &event)
    end
  end
end
