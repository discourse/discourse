# frozen_string_literal: true

module BackupsHelpers
  def setup_local_backups
    root_directory = Dir.mktmpdir
    SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL
    root_directory
  end

  def teardown_local_backups(root_directory:)
    FileUtils.remove_dir(root_directory, true)
  end

  def create_local_backup_file(root_directory:, db_name:, filename:, last_modified:, size_in_bytes:)
    path = File.join(root_directory, db_name)
    Dir.mkdir(path) unless Dir.exist?(path)

    path = File.join(path, filename)
    return if File.exist?(path)

    FileUtils.touch(path)
    File.truncate(path, size_in_bytes)

    time = Time.parse(last_modified)
    File.utime(time, time, path)

    path
  end
end
