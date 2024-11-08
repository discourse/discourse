# frozen_string_literal: true

GEOLITE_DBS = %w[GeoLite2-City GeoLite2-ASN].freeze

desc "downloads MaxMind's GeoLite2-City databases"
task "maxminddb:get" => "environment" do
  GEOLITE_DBS.each do |name|
    puts "Downloading MaxMindDb's #{name}..."
    DiscourseIpInfo.mmdb_download(name)
  end
end

def get_mmdb_time(root_path)
  mmdb_time = nil

  GEOLITE_DBS.each do |name|
    path = File.join(root_path, "#{name}.mmdb")

    if File.exist?(path)
      mmdb_time = File.mtime(path)
    else
      mmdb_time = nil
      break
    end
  end

  mmdb_time
end

def copy_maxmind(from_path, to_path)
  puts "Copying MaxMindDB from #{from_path} to #{to_path}"

  GEOLITE_DBS.each do |name|
    from = File.join(from_path, "#{name}.mmdb")
    to = File.join(to_path, "#{name}.mmdb")
    FileUtils.cp(from, to, preserve: true)
    FileUtils.touch(to)
  end
end

maxmind_thread = nil

task "maxminddb:refresh": "environment" do
  refresh_days = GlobalSetting.refresh_maxmind_db_during_precompile_days
  next if refresh_days.to_i <= 0

  mmdb_time = get_mmdb_time(DiscourseIpInfo.path)

  if GlobalSetting.maxmind_backup_path.present?
    backup_mmdb_time = get_mmdb_time(GlobalSetting.maxmind_backup_path)
    puts "Detected MaxMindDB backup (downloaded: #{backup_mmdb_time}) at #{GlobalSetting.maxmind_backup_path}"
    mmdb_time ||= backup_mmdb_time
  end

  if backup_mmdb_time && backup_mmdb_time >= mmdb_time
    copy_maxmind(GlobalSetting.maxmind_backup_path, DiscourseIpInfo.path)
    mmdb_time = backup_mmdb_time
  end

  if mmdb_time && mmdb_time >= refresh_days.days.ago
    puts "Skip downloading MaxMindDB as it was last downloaded at #{mmdb_time}"
    next
  end

  puts "Downloading MaxMindDB..."

  name = "unknown"

  begin
    GEOLITE_DBS.each do |db|
      name = db
      DiscourseIpInfo.mmdb_download(db)
    end

    if GlobalSetting.maxmind_backup_path.present?
      copy_maxmind(DiscourseIpInfo.path, GlobalSetting.maxmind_backup_path)
    end
  rescue OpenURI::HTTPError => e
    STDERR.puts("*" * 100)
    STDERR.puts("MaxMindDB (#{name}) could not be downloaded: #{e}")
    STDERR.puts("*" * 100)
    Rails.logger.warn("MaxMindDB (#{name}) could not be downloaded: #{e}")
  end
end
