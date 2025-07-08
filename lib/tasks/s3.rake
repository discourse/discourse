# frozen_string_literal: true

def brotli_s3_path(path)
  ext = File.extname(path)
  "#{path[0..-ext.length]}br#{ext}"
end

def gzip_s3_path(path)
  ext = File.extname(path)
  "#{path[0..-ext.length]}gz#{ext}"
end

def existing_assets
  @existing_assets ||= Set.new(helper.list("assets/").map(&:key))
end

def prefix_s3_path(path)
  path = File.join(helper.s3_bucket_folder_path, path) if helper.s3_bucket_folder_path
  path
end

def should_skip?(path)
  return false if ENV["FORCE_S3_UPLOADS"]
  existing_assets.include?(prefix_s3_path(path))
end

def upload(path, remote_path, content_type, content_encoding = nil, logger:)
  options = {
    cache_control: "max-age=31556952, public, immutable",
    content_type: content_type,
  }.merge(Discourse.store.default_s3_options(secure: false))

  options[:content_encoding] = content_encoding if content_encoding

  if should_skip?(remote_path)
    logger << "Skipping: #{remote_path}\n"
  else
    logger << "Uploading: #{remote_path}\n"

    File.open(path) { |file| helper.upload(file, remote_path, options) }
  end
end

def use_db_s3_config
  ENV["USE_DB_S3_CONFIG"]
end

def helper
  @helper ||= S3Helper.build_from_config(use_db_s3_config: use_db_s3_config)
end

def assets
  load_path = Rails.application.assets.load_path

  results = Set.new

  load_path.assets.each do |asset|
    fullpath = "#{Rails.root}/public/assets/#{asset.digested_path}"

    content_type = MiniMime.lookup_by_filename(fullpath)&.content_type
    content_type ||= "application/json" if fullpath.end_with?(".map")

    next unless content_type

    asset_path = "assets/#{asset.digested_path}"
    results << [fullpath, asset_path, content_type]

    if File.exist?(fullpath + ".br")
      results << [fullpath + ".br", brotli_s3_path(asset_path), content_type, "br"]
    end

    if File.exist?(fullpath + ".gz")
      results << [fullpath + ".gz", gzip_s3_path(asset_path), content_type, "gzip"]
    end
  end

  results.to_a
end

def asset_paths
  Set.new(assets.map { |_, asset_path| asset_path })
end

def ensure_s3_configured!
  unless GlobalSetting.use_s3? || use_db_s3_config
    STDERR.puts "ERROR: Ensure S3 is configured in config/discourse.conf or environment vars"
    exit 1
  end
end

task "s3:ensure_cors_rules" => :environment do
  ensure_s3_configured!

  puts "Installing CORS rules..."
  result = S3CorsRulesets.sync(use_db_s3_config: use_db_s3_config)

  if !result
    puts "skipping"
    next
  end

  puts "Assets rules status: #{result[:assets_rules_status]}."
  puts "Backup rules status: #{result[:backup_rules_status]}."
  puts "Direct upload rules status: #{result[:direct_upload_rules_status]}."
end

task "s3:upload_assets" => [:environment, "s3:ensure_cors_rules"] do
  logger = Logger.new(STDOUT)
  assets.each { |asset| upload(*asset, logger:) }
end

task "s3:expire_missing_assets" => :environment do
  ensure_s3_configured!

  puts "Checking for stale S3 assets..."

  if Discourse.readonly_mode?
    puts "Discourse is in readonly mode. Skipping s3 asset deletion in case this is a read-only mirror of a live site."
    exit 0
  end

  assets_to_delete = existing_assets.dup

  # Check that all current assets are uploaded, and remove them from the to_delete list
  asset_paths.each do |current_asset_path|
    uploaded = assets_to_delete.delete?(prefix_s3_path(current_asset_path))
    if !uploaded
      puts "A current asset does not exist on S3 (#{current_asset_path}). Aborting cleanup task."
      exit 1
    end
  end

  if assets_to_delete.size > 0
    puts "Found #{assets_to_delete.size} assets to delete..."

    assets_to_delete.each do |to_delete|
      if !to_delete.start_with?(prefix_s3_path("assets/"))
        # Sanity check, this should never happen
        raise "Attempted to delete a non-/asset S3 path (#{to_delete}). Aborting"
      end
    end

    assets_to_delete.each_slice(500) do |slice|
      message = "Deleting #{slice.size} assets...\n"
      message += slice.join("\n").indent(2)
      puts message
      helper.delete_objects(slice)
      puts "... done"
    end
  else
    puts "No stale assets found"
  end
end
