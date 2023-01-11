# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::DatabaseRestorer, type: :multisite do
  include_context "with shared stuff"

  let(:current_db) { RailsMultisite::ConnectionManagement.current_db }

  subject { BackupRestore::DatabaseRestorer.new(logger, current_db) }

  describe "#restore" do
    context "with database connection" do
      it "reconnects to the correct database" do
        RailsMultisite::ConnectionManagement.establish_connection(db: "second")
        execute_stubbed_restore
        expect(RailsMultisite::ConnectionManagement.current_db).to eq("second")
      end
    end
  end
end
