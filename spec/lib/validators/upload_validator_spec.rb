# frozen_string_literal: true

RSpec.describe UploadValidator do
  subject(:validator) { described_class.new }

  describe "validate" do
    fab!(:user)
    let(:filename) { "discourse.csv" }
    let(:csv_file) { file_from_fixtures(filename, "csv") }

    it "should create an invalid upload when the filename is blank" do
      SiteSetting.authorized_extensions = "*"
      created_upload = UploadCreator.new(csv_file, nil).create_for(user.id)
      validator.validate(created_upload)
      expect(created_upload).to_not be_valid
      expect(created_upload.errors.full_messages.first).to include(
        I18n.t("activerecord.errors.messages.blank"),
      )
    end

    it "allows 'gz' as extension when uploading export file" do
      SiteSetting.authorized_extensions = ""

      expect(
        UploadCreator.new(csv_file, "#{filename}.zip", for_export: true).create_for(user.id),
      ).to be_valid
    end

    it "allows uses max_export_file_size_kb when uploading export file" do
      SiteSetting.max_attachment_size_kb = "0"
      SiteSetting.authorized_extensions = "zip"

      expect(
        UploadCreator.new(csv_file, "#{filename}.zip", for_export: true).create_for(user.id),
      ).to be_valid
    end

    describe "size validation" do
      it "does not allow images that are too large" do
        SiteSetting.max_image_size_kb = 1536
        upload =
          Fabricate.build(
            :upload,
            user: Fabricate(:admin),
            original_filename: "test.png",
            filesize: 2_097_152,
          )
        validator.validate(upload)
        expect(upload.errors.full_messages.first).to eq(
          "Filesize #{I18n.t("upload.images.too_large_humanized", max_size: "1.5 MB")}",
        )
      end
    end

    describe "when allow_staff_to_upload_any_file_in_pm is true" do
      it "should allow uploads for pm" do
        upload =
          Fabricate.build(
            :upload,
            user: Fabricate(:admin),
            original_filename: "test.ico",
            for_private_message: true,
          )

        expect(validator.validate(upload)).to eq(true)
      end

      describe "for a normal user" do
        it "should not allow uploads for pm" do
          upload =
            Fabricate.build(
              :upload,
              user: Fabricate(:user),
              original_filename: "test.ico",
              for_private_message: true,
            )

          expect(validator.validate(upload)).to eq(nil)
        end
      end
    end

    describe "upload for site settings" do
      fab!(:admin)
      fab!(:user)

      let(:upload) do
        Fabricate.build(:upload, user: admin, original_filename: "test.png", for_site_setting: true)
      end

      it "allows image uploads for staff" do
        expect(validator.validate(upload)).to eq(true)
      end

      it "rejects non-image uploads when no authorized_extensions specified" do
        upload.original_filename = "test.txt"
        validator.validate(upload)
        expect(upload.errors[:original_filename]).to include(I18n.t("upload.images_only"))
      end

      it "rejects uploads from non-staff users" do
        upload.user = user
        validator.validate(upload)
        expect(upload.errors[:base]).to include(I18n.t("upload.unauthorized"))
      end

      it "validates image file size" do
        SiteSetting.max_image_size_kb = 1
        upload.filesize = 10.kilobytes
        validator.validate(upload)
        expect(upload.errors[:filesize]).to be_present
      end

      context "with authorized_extensions" do
        before do
          upload.site_setting_name = "test_setting"
          SiteSetting
            .type_supervisor
            .stubs(:type_hash)
            .with(:test_setting)
            .returns({ type: "upload", authorized_extensions: "txt|md" })
        end

        it "allows matching extensions" do
          upload.original_filename = "file.txt"
          expect(validator.validate(upload)).to eq(true)

          upload.original_filename = "file.md"
          expect(validator.validate(upload)).to eq(true)
        end

        it "rejects non-matching extensions" do
          upload.original_filename = "script.js"
          validator.validate(upload)
          expect(upload.errors[:original_filename]).to include(
            I18n.t("upload.unauthorized", authorized_extensions: "txt|md"),
          )
        end

        it "validates attachment file size for non-images" do
          SiteSetting.max_attachment_size_kb = 1
          upload.original_filename = "file.txt"
          upload.filesize = 10.kilobytes
          validator.validate(upload)
          expect(upload.errors[:filesize]).to be_present
        end

        it "validates image file size for images" do
          SiteSetting
            .type_supervisor
            .stubs(:type_hash)
            .with(:test_setting)
            .returns({ type: "upload", authorized_extensions: "png" })
          SiteSetting.max_image_size_kb = 1
          upload.original_filename = "image.png"
          upload.filesize = 10.kilobytes
          validator.validate(upload)
          expect(upload.errors[:filesize]).to be_present
        end
      end

      context "with site_setting_name but no authorized_extensions" do
        before do
          upload.site_setting_name = "image_only_setting"
          SiteSetting
            .type_supervisor
            .stubs(:type_hash)
            .with(:image_only_setting)
            .returns({ type: "upload" })
        end

        it "falls back to images only" do
          upload.original_filename = "test.txt"
          validator.validate(upload)
          expect(upload.errors[:original_filename]).to include(I18n.t("upload.images_only"))
        end
      end

      context "with max_file_size_kb" do
        before do
          upload.site_setting_name = "limited_upload"
          upload.original_filename = "file.txt"
        end

        it "enforces the setting-specific file size limit" do
          SiteSetting
            .type_supervisor
            .stubs(:type_hash)
            .with(:limited_upload)
            .returns({ type: "upload", authorized_extensions: "txt", max_file_size_kb: 5 })
          upload.filesize = 10.kilobytes
          validator.validate(upload)
          expect(upload.errors[:filesize]).to be_present
        end

        it "allows files within the limit" do
          SiteSetting
            .type_supervisor
            .stubs(:type_hash)
            .with(:limited_upload)
            .returns({ type: "upload", authorized_extensions: "txt", max_file_size_kb: 100 })
          upload.filesize = 50.kilobytes
          expect(validator.validate(upload)).to eq(true)
        end

        it "uses setting limit instead of global attachment limit" do
          SiteSetting.max_attachment_size_kb = 1
          SiteSetting
            .type_supervisor
            .stubs(:type_hash)
            .with(:limited_upload)
            .returns({ type: "upload", authorized_extensions: "txt", max_file_size_kb: 100 })
          upload.filesize = 50.kilobytes
          expect(validator.validate(upload)).to eq(true)
        end
      end
    end
  end
end
