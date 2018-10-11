require 'rails_helper'
require 'backup_restore/local_backup_store'
require_relative 'shared_examples_for_backup_store'

describe BackupRestore::LocalBackupStore do
  before(:all) do
    @base_directory = Dir.mktmpdir
    @paths = []
  end

  after(:all) do
    FileUtils.remove_dir(@base_directory, true)
  end

  before do
    SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL
  end

  subject(:store) { BackupRestore::BackupStore.create(base_directory: @base_directory) }
  let(:expected_type) { BackupRestore::LocalBackupStore }

  it_behaves_like "backup store"

  it "is not a remote store" do
    expect(store.remote?).to eq(false)
  end

  def create_backups
    create_file(filename: "b.tar.gz", last_modified: "2018-09-13T15:10:00Z", size_in_bytes: 17)
    create_file(filename: "a.tgz", last_modified: "2018-02-11T09:27:00Z", size_in_bytes: 29)
    create_file(filename: "r.sql.gz", last_modified: "2017-12-20T03:48:00Z", size_in_bytes: 11)
    create_file(filename: "no-backup.txt", last_modified: "2018-09-05T14:27:00Z", size_in_bytes: 12)
  end

  def remove_backups
    @paths.each { |path| File.delete(path) if File.exists?(path) }
    @paths.clear
  end

  def create_file(filename:, last_modified:, size_in_bytes:)
    path = File.join(@base_directory, filename)
    return if File.exists?(path)

    @paths << path
    FileUtils.touch(path)
    File.truncate(path, size_in_bytes)

    time = Time.parse(last_modified)
    File.utime(time, time, path)
  end

  def source_regex(filename)
    path = File.join(@base_directory, filename)
    /^#{Regexp.escape(path)}$/
  end
end
