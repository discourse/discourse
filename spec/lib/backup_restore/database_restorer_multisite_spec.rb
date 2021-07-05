# frozen_string_literal: true

require "rails_helper"
require_relative "shared_context_for_backup_restore"

describe BackupRestore::DatabaseRestorer, type: :multisite do
  include_context "shared stuff"

  let(:current_db) { RailsMultisite::ConnectionManagement.current_db }

  subject { BackupRestore::DatabaseRestorer.new(logger, current_db) }

  describe "#restore" do
    context "database connection" do
      it "reconnects to the correct database" do
        RailsMultisite::ConnectionManagement.establish_connection(db: "second")
        execute_stubbed_restore
        expect(RailsMultisite::ConnectionManagement.current_db).to eq("second")
      end
    end
  end
end
