# frozen_string_literal: true

require "backup_restore/local_backup_store"
require_relative "shared_examples_for_backup_store"

RSpec.describe BackupRestore::LocalBackupStore do
  subject(:store) { BackupRestore::BackupStore.create(root_directory: @root_directory) }

  before do
    @paths = []
    @root_directory = setup_local_backups
  end

  let(:expected_type) { BackupRestore::LocalBackupStore }

  it_behaves_like "backup store"

  it "is not a remote store" do
    expect(store.remote?).to eq(false)
  end

  def create_backups
    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "default",
      filename: "b.tar.gz",
      last_modified: "2018-09-13T15:10:00Z",
      size_in_bytes: 17,
    )
    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "default",
      filename: "a.tgz",
      last_modified: "2018-02-11T09:27:00Z",
      size_in_bytes: 29,
    )
    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "default",
      filename: "r.sql.gz",
      last_modified: "2017-12-20T03:48:00Z",
      size_in_bytes: 11,
    )
    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "default",
      filename: "no-backup.txt",
      last_modified: "2018-09-05T14:27:00Z",
      size_in_bytes: 12,
    )
    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "default/subfolder",
      filename: "c.tar.gz",
      last_modified: "2019-01-24T18:44:00Z",
      size_in_bytes: 23,
    )

    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "second",
      filename: "multi-2.tar.gz",
      last_modified: "2018-11-27T03:16:54Z",
      size_in_bytes: 19,
    )
    create_local_backup_file(
      root_directory: @root_directory,
      db_name: "second",
      filename: "multi-1.tar.gz",
      last_modified: "2018-11-26T03:17:09Z",
      size_in_bytes: 22,
    )
  end

  def remove_backups
    teardown_local_backups(root_directory: @root_directory)
  end

  def source_regex(db_name, filename, multisite:)
    path = File.join(@root_directory, db_name, filename)
    /^#{Regexp.escape(path)}$/
  end
end
