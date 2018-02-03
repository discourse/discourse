require 'rails_helper'

RSpec.describe Admin::BackupsController do
  let(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe "#index" do
    it "raises an error when backups are disabled" do
      SiteSetting.enable_backups = false
      get "/admin/backups.json"
      expect(response).not_to be_success
    end
  end

  describe '#rollback' do
    it 'should rollback the restore' do
      BackupRestore.expects(:rollback!)

      post "/admin/backups/rollback.json"

      expect(response).to be_success
    end

    it 'should not allow rollback via a GET request' do
      get "/admin/backups/rollback.json"
      expect(response.status).to eq(404)
    end
  end

  describe '#cancel' do
    it "should cancel an backup" do
      BackupRestore.expects(:cancel!)

      delete "/admin/backups/cancel.json"

      expect(response).to be_success
    end

    it 'should not allow cancel via a GET request' do
      get "/admin/backups/cancel.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#email" do
    let(:backup_filename) { "test.tar.gz" }
    let(:backup) { Backup.new(backup_filename) }

    it "enqueues email job" do
      Backup.expects(:[]).with(backup_filename).returns(backup)

      Jobs.expects(:enqueue).with(:download_backup_email,
        user_id: admin.id,
        backup_file_path: 'http://www.example.com/admin/backups/test.tar.gz'
      )

      put "/admin/backups/#{backup_filename}.json"

      expect(response).to be_success
    end

    it "returns 404 when the backup does not exist" do
      put "/admin/backups/#{backup_filename}.json"

      expect(response).to be_not_found
    end

  end
end
