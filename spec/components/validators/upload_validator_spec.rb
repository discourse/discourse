# frozen_string_literal: true

require 'rails_helper'

describe UploadValidator do
  subject(:validator) { described_class.new }

  describe 'validate' do
    fab!(:user) { Fabricate(:user) }
    let(:filename) { "discourse.csv" }
    let(:csv_file) { file_from_fixtures(filename, "csv") }

    it "should create an invalid upload when the filename is blank" do
      SiteSetting.authorized_extensions = "*"
      created_upload = UploadCreator.new(csv_file, nil).create_for(user.id)
      validator.validate(created_upload)
      expect(created_upload).to_not be_valid
      expect(created_upload.errors.full_messages.first).to include(I18n.t("activerecord.errors.messages.blank"))
    end

    it "allows 'gz' as extension when uploading export file" do
      SiteSetting.authorized_extensions = ""

      expect(UploadCreator.new(csv_file, "#{filename}.zip", for_export: true).create_for(user.id)).to be_valid
    end

    it "allows uses max_export_file_size_kb when uploading export file" do
      SiteSetting.max_attachment_size_kb = "0"
      SiteSetting.authorized_extensions = "zip"

      expect(UploadCreator.new(csv_file, "#{filename}.zip", for_export: true).create_for(user.id)).to be_valid
    end

    describe 'when allow_staff_to_upload_any_file_in_pm is true' do
      it 'should allow uploads for pm' do
        upload = Fabricate.build(:upload,
          user: Fabricate(:admin),
          original_filename: 'test.ico',
          for_private_message: true
        )

        expect(subject.validate(upload)).to eq(true)
      end

      describe 'for a normal user' do
        it 'should not allow uploads for pm' do
          upload = Fabricate.build(:upload,
            user: Fabricate(:user),
            original_filename: 'test.ico',
            for_private_message: true
          )

          expect(subject.validate(upload)).to eq(nil)
        end
      end
    end

    describe 'upload for site settings' do
      fab!(:user) { Fabricate(:admin) }

      let(:upload) do
        Fabricate.build(:upload,
          user: user,
          original_filename: 'test.ico',
          for_site_setting: true
        )
      end

      before do
        SiteSetting.authorized_extensions = 'png'
      end

      describe 'for admin user' do
        it 'should allow the upload' do
          expect(subject.validate(upload)).to eq(true)
        end

        describe 'when filename is invalid' do
          it 'should not allow the upload' do
            upload.original_filename = 'test.txt'
            expect(subject.validate(upload)).to eq(nil)
          end
        end
      end

      describe 'for normal user' do
        fab!(:user) { Fabricate(:user) }

        it 'should not allow the upload' do
          expect(subject.validate(upload)).to eq(nil)
        end
      end
    end
  end
end
