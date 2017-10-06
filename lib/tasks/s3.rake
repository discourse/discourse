require_dependency "s3_helper"

def brotli_s3_path(path)
  ext = File.extname(path)
  "#{path[0..-ext.length]}br#{ext}"
end

def gzip_s3_path(path)
  ext = File.extname(path)
  "#{path[0..-ext.length]}gz#{ext}"
end

def should_skip?(path)
  return false if ENV['FORCE_S3_UPLOADS']
  @existing_assets ||= Set.new(helper.list("assets/").map(&:key))
  @existing_assets.include?(path)
end

def upload(path, remote_path, content_type, content_encoding = nil)

  options = {
    cache_control: 'max-age=31556952, public, immutable',
    content_type: content_type,
    acl: 'public-read',
    tagging: ''
  }

  if content_encoding
    options[:content_encoding] = content_encoding
  end

  if should_skip?(remote_path)
    puts "Skipping: #{remote_path}"
  else
    puts "Uploading: #{remote_path}"
    helper.upload(path, remote_path, options)
  end
end

def helper
  @helper ||= S3Helper.new(GlobalSetting.s3_bucket.downcase, '', S3Helper.s3_options(GlobalSetting))
end

def assets
  cached = Rails.application.assets&.cached
  manifest = Sprockets::Manifest.new(cached, Rails.root + 'public/assets', Rails.application.config.assets.manifest)

  results = []

  manifest.assets.each do |_, path|
    fullpath = (Rails.root + "public/assets/#{path}").to_s

    content_type = MiniMime.lookup_by_filename(fullpath).content_type

    asset_path = "assets/#{path}"
    results << [fullpath, asset_path, content_type]

    if File.exist?(fullpath + '.br')
      results << [fullpath + '.br', brotli_s3_path(asset_path), content_type, 'br']
    end

    if File.exist?(fullpath + '.gz')
      results << [fullpath + '.gz', gzip_s3_path(asset_path), content_type, 'gzip']
    end

    if File.exist?(fullpath + '.map')
      results << [fullpath + '.map', asset_path + '.map', 'application/json']
    end
  end

  results
end

def in_manifest
  found = []
  assets.each do |_, path|
    fullpath = (Rails.root + "public/assets/#{path}").to_s

    asset_path = "assets/#{path}"
    found << asset_path

    if File.exist?(fullpath + '.br')
      found << brotli_s3_path(asset_path)
    end

    if File.exist?(fullpath + '.gz')
      found << gzip_s3_path(asset_path)
    end

    if File.exist?(fullpath + '.map')
      found << asset_path + '.map'
    end

  end
  Set.new(found)
end

def ensure_s3_configured!
  unless GlobalSetting.use_s3?
    STDERR.puts "ERROR: Ensure S3 is configured in config/discourse.conf of environment vars"
    exit 1
  end
end

task 's3:upload_assets' => :environment do
  ensure_s3_configured!

  assets.each do |asset|
    upload(*asset)
  end
end

task 's3:expire_missing_assets' => :environment do
  ensure_s3_configured!
  keep = in_manifest

  count = 0
  puts "Ensuring AWS assets are tagged correctly for removal"
  helper.list.each do |f|
    if keep.include?(f.key)
      helper.tag_file(f.key, old: true)
      count += 1
    else
      # ensure we do not delete this by mistake
      helper.tag_file(f.key, {})
    end
  end

  puts "#{count} assets were flagged for removal in 10 days"

  puts "Ensuring AWS rule exists for purging old assets"
  #helper.update_lifecycle("delete_old_assets", 10, prefix: 'old=true')

  puts "Waiting on https://github.com/aws/aws-sdk-ruby/issues/1623"

end
