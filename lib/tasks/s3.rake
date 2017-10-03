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
  return true if ENV['FORCE_S3_UPLOADS']
  @existing_assets ||= Set.new(helper.list.map(&:key))
  @existing_assets.include?('assets/' + path)
end

def upload_asset(helper, path, recurse: true, content_type: nil, fullpath: nil, content_encoding: nil)
  fullpath ||= (Rails.root + "public/assets/#{path}").to_s

  content_type ||= MiniMime.lookup_by_filename(path).content_type

  options = {
    cache_control: 'max-age=31556952, public, immutable',
    content_type: content_type,
    acl: 'public-read',
    tagging: ''
  }

  if content_encoding
    options[:content_encoding] = content_encoding
  end

  if should_skip?(path)
    puts "Skipping: #{path}"
  else
    puts "Uploading: #{path}"
    helper.upload(fullpath, path, options)
  end

  if recurse
    if File.exist?(fullpath + ".br")
      brotli_path = brotli_s3_path(path)
      upload_asset(helper, brotli_path,
        fullpath: fullpath + ".br",
        recurse: false,
        content_type: content_type,
        content_encoding: 'br'
      )
    end

    if File.exist?(fullpath + ".gz")
      gzip_path = gzip_s3_path(path)
      upload_asset(helper, gzip_path,
        fullpath: fullpath + ".gz",
        recurse: false,
        content_type: content_type,
        content_encoding: 'gzip'
      )
    end

    if File.exist?(fullpath + ".map")
      upload_asset(helper, path + ".map", recurse: false, content_type: 'application/json')
    end
  end
end

def assets
  cached = Rails.application.assets&.cached
  manifest = Sprockets::Manifest.new(cached, Rails.root + 'public/assets', Rails.application.config.assets.manifest)

  raise Discourse::SiteSettingMissing.new("s3_upload_bucket") if SiteSetting.s3_upload_bucket.blank?
  manifest.assets
end

def helper
  @helper ||= S3Helper.new(SiteSetting.s3_upload_bucket.downcase + '/assets')
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

task 's3:upload_assets' => :environment do
  assets.each do |name, fingerprint|
    upload_asset(helper, fingerprint)
  end
end

task 's3:expire_missing_assets' => :environment do
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
