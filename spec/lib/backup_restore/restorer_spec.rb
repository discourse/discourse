# frozen_string_literal: true

RSpec.describe BackupRestore::Restorer do
  fab!(:admin)

  subject(:restorer) do
    described_class.new(user_id: admin.id, filename: "backup.tar.gz", factory: factory)
  end

  let(:factory) { BackupRestore::Factory.new(user_id: admin.id) }
  let(:database_restorer) { stub_everything("database restorer") }

  before do
    SiteSetting.allow_restore = true

    factory.stubs(:create_system_interface).returns(stub_everything("system interface"))
    factory.stubs(:create_backup_file_handler).returns(
      stub_everything("backup file handler", decompress: %w[backup.tar.gz /tmp/restore dump.sql]),
    )
    factory.stubs(:create_database_restorer).returns(database_restorer)
    factory.stubs(:create_uploads_restorer).returns(stub_everything("uploads restorer"))
    factory.stubs(:create_meta_data_handler).returns(stub_everything("meta data handler"))

    Discourse::Application.stubs(:load_tasks)
    Rake::Task.stubs(:[]).with("db:seed").returns(stub_everything("db:seed"))
  end

  describe "#run" do
    it "tells every process to flush the restored database's schema cache" do
      messages = MessageBus.track_publish("/schema_cache_flush") { restorer.run }

      expect(restorer.success).to eq(true)
      expect(messages.map(&:data)).to contain_exactly(
        RailsMultisite::ConnectionManagement.current_db,
      )
    end

    it "does not flush schema caches when the restore fails" do
      database_restorer.stubs(:restore).raises(StandardError, "restore failed")

      messages = MessageBus.track_publish("/schema_cache_flush") { restorer.run }

      expect(restorer.success).to eq(false)
      expect(messages).to be_empty
    end
  end
end
