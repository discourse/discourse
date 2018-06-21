require 'rails_helper'
require_dependency 'validators/upload_validator'

describe Validators::UploadValidator do
  subject(:validator) { described_class.new }

  describe 'validate' do
    let(:user) { Fabricate(:user) }
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

      created_upload = UploadCreator.new(csv_file, "#{filename}.gz", for_export: true).create_for(user.id)
      expect(created_upload).to be_valid
    end

  end
end
