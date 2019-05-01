# frozen_string_literal: true

require 'rails_helper'
require 'backup_restore/local_backup_store'
require_relative 'shared_examples_for_backup_store'

describe BackupRestore::LocalBackupStore do
  before(:all) do
    @root_directory = Dir.mktmpdir
    @paths = []
  end

  after(:all) do
    FileUtils.remove_dir(@root_directory, true)
  end

  before do
    SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL
  end

  subject(:store) { BackupRestore::BackupStore.create(root_directory: @root_directory) }
  let(:expected_type) { BackupRestore::LocalBackupStore }

  it_behaves_like "backup store"

  it "is not a remote store" do
    expect(store.remote?).to eq(false)
  end

  def create_backups
    create_file(db_name: "default", filename: "b.tar.gz", last_modified: "2018-09-13T15:10:00Z", size_in_bytes: 17)
    create_file(db_name: "default", filename: "a.tgz", last_modified: "2018-02-11T09:27:00Z", size_in_bytes: 29)
    create_file(db_name: "default", filename: "r.sql.gz", last_modified: "2017-12-20T03:48:00Z", size_in_bytes: 11)
    create_file(db_name: "default", filename: "no-backup.txt", last_modified: "2018-09-05T14:27:00Z", size_in_bytes: 12)
    create_file(db_name: "default/subfolder", filename: "c.tar.gz", last_modified: "2019-01-24T18:44:00Z", size_in_bytes: 23)

    create_file(db_name: "second", filename: "multi-2.tar.gz", last_modified: "2018-11-27T03:16:54Z", size_in_bytes: 19)
    create_file(db_name: "second", filename: "multi-1.tar.gz", last_modified: "2018-11-26T03:17:09Z", size_in_bytes: 22)
  end

  def remove_backups
    @paths.each { |path| File.delete(path) if File.exists?(path) }
    @paths.clear
  end

  def create_file(db_name:, filename:, last_modified:, size_in_bytes:)
    path = File.join(@root_directory, db_name)
    Dir.mkdir(path) unless Dir.exists?(path)

    path = File.join(path, filename)
    return if File.exists?(path)

    @paths << path
    FileUtils.touch(path)
    File.truncate(path, size_in_bytes)

    time = Time.parse(last_modified)
    File.utime(time, time, path)
  end

  def source_regex(db_name, filename, multisite:)
    path = File.join(@root_directory, db_name, filename)
    /^#{Regexp.escape(path)}$/
  end
end
