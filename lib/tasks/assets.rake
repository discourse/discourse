# frozen_string_literal: true

task 'assets:precompile:before' do

  require 'uglifier'
  require 'open3'

  unless %w{profile production}.include? Rails.env
    raise "rake assets:precompile should only be run in RAILS_ENV=production, you are risking unminified assets"
  end

  # Ensure we ALWAYS do a clean build
  # We use many .erbs that get out of date quickly, especially with plugins
  STDERR.puts "Purging temp files"
  `rm -fr #{Rails.root}/tmp/cache`

  # Ensure we clear emoji cache before pretty-text/emoji/data.js.es6.erb
  # is recompiled
  Emoji.clear_cache

  $node_compress = `which terser`.present? && !ENV['SKIP_NODE_UGLIFY']

  unless ENV['USE_SPROCKETS_UGLIFY']
    $bypass_sprockets_uglify = true
    Rails.configuration.assets.js_compressor = nil
    Rails.configuration.assets.gzip = false
  end

  STDERR.puts "Bundling assets"

  # in the past we applied a patch that removed asset postfixes, but it is terrible practice
  # leaving very complicated build issues
  # https://github.com/rails/sprockets-rails/issues/49

  require 'sprockets'
  require 'digest/sha1'

  if ENV['EMBER_CLI_PROD_ASSETS'] != "0"
    # Remove the assets that Ember CLI will handle for us
    Rails.configuration.assets.precompile.reject! do |asset|
      asset.is_a?(String) && is_ember_cli_asset?(asset)
    end
  end
end

task 'assets:precompile:css' => 'environment' do
  if ENV["DONT_PRECOMPILE_CSS"] == "1"
    STDERR.puts "Skipping CSS precompilation, ensure CSS lives in a shared directory across hosts"
  else
    STDERR.puts "Start compiling CSS: #{Time.zone.now}"

    RailsMultisite::ConnectionManagement.each_connection do |db|
      # CSS will get precompiled during first request if tables do not exist.
      if ActiveRecord::Base.connection.table_exists?(Theme.table_name)
        STDERR.puts "-------------"
        STDERR.puts "Compiling CSS for #{db} #{Time.zone.now}"
        begin
          Stylesheet::Manager.precompile_css if db == "default"
          Stylesheet::Manager.precompile_theme_css
        rescue PG::UndefinedColumn, ActiveModel::MissingAttributeError, NoMethodError => e
          STDERR.puts "#{e.class} #{e.message}: #{e.backtrace.join("\n")}"
          STDERR.puts "Skipping precompilation of CSS cause schema is old, you are precompiling prior to running migrations."
        end
      end
    end

    STDERR.puts "Done compiling CSS: #{Time.zone.now}"
  end
end

task 'assets:flush_sw' => 'environment' do
  begin
    hostname = Discourse.current_hostname
    default_port = SiteSetting.force_https? ? 443 : 80
    port = SiteSetting.port.to_i > 0 ? SiteSetting.port : default_port
    STDERR.puts "Flushing service worker script"
    `curl -s -m 1 --resolve '#{hostname}:#{port}:127.0.0.1' #{Discourse.base_url}/service-worker.js > /dev/null`
    STDERR.puts "done"
  rescue
    STDERR.puts "Warning: unable to flush service worker script"
  end
end

def is_ember_cli_asset?(name)
  return false if ENV['EMBER_CLI_PROD_ASSETS'] == '0'
  %w(application.js admin.js ember_jquery.js pretty-text-bundle.js start-discourse.js vendor.js).include?(name)
end

def assets_path
  "#{Rails.root}/public/assets"
end

def global_path_klass
  @global_path_klass ||= Class.new do
    extend GlobalPath
  end
end

def cdn_path(p)
  global_path_klass.cdn_path(p)
end

def cdn_relative_path(p)
  global_path_klass.cdn_relative_path(p)
end

def compress_node(from, to)
  to_path = "#{assets_path}/#{to}"
  assets = cdn_relative_path("/assets")
  assets_additional_path = (d = File.dirname(from)) == "." ? "" : "/#{d}"
  source_map_root = assets + assets_additional_path
  source_map_url = "#{File.basename(to)}.map"
  base_source_map = assets_path + assets_additional_path

  cmd = <<~EOS
    terser '#{assets_path}/#{from}' -m -c -o '#{to_path}' --source-map "base='#{base_source_map}',root='#{source_map_root}',url='#{source_map_url}'"
  EOS

  STDERR.puts cmd
  result = `#{cmd} 2>&1`
  unless $?.success?
    STDERR.puts result
    exit 1
  end

  result
end

def compress_ruby(from, to)
  data = File.read("#{assets_path}/#{from}")

  uglified, map = Uglifier.new(comments: :none,
                               source_map: {
                                 filename: File.basename(from),
                                 output_filename: File.basename(to)
                               }
                              )
    .compile_with_map(data)
  dest = "#{assets_path}/#{to}"

  File.write(dest, uglified << "\n//# sourceMappingURL=#{cdn_path "/assets/#{to}.map"}")
  File.write(dest + ".map", map)

  GC.start
end

def gzip(path)
  STDERR.puts "gzip -f -c -9 #{path} > #{path}.gz"
  STDERR.puts `gzip -f -c -9 #{path} > #{path}.gz`.strip
  raise "gzip compression failed: exit code #{$?.exitstatus}" if $?.exitstatus != 0
end

# different brotli versions use different parameters
def brotli_command(path, max_compress)
  compression_quality = max_compress ? "11" : "6"
  "brotli -f --quality=#{compression_quality} #{path} --output=#{path}.br"
end

def brotli(path, max_compress)
  STDERR.puts brotli_command(path, max_compress)
  STDERR.puts `#{brotli_command(path, max_compress)}`
  raise "brotli compression failed: exit code #{$?.exitstatus}" if $?.exitstatus != 0
  STDERR.puts `chmod +r #{path}.br`.strip
  raise "chmod failed: exit code #{$?.exitstatus}" if $?.exitstatus != 0
end

def max_compress?(path, locales)
  return false if Rails.configuration.assets.skip_minification.include? path
  return false if is_ember_cli_asset?(path)
  return true unless path.include? "locales/"

  path_locale = path.delete_prefix("locales/").delete_suffix(".js")
  return true if locales.include? path_locale

  false
end

def compress(from, to)
  if $node_compress
    compress_node(from, to)
  else
    compress_ruby(from, to)
  end
end

def concurrent?
  if ENV["SPROCKETS_CONCURRENT"] == "1"
    concurrent_compressors = []
    executor = Concurrent::FixedThreadPool.new(Concurrent.processor_count)
    yield(Proc.new { |&block| concurrent_compressors << Concurrent::Future.execute(executor: executor) { block.call } })
    concurrent_compressors.each(&:wait!)
  else
    yield(Proc.new { |&block| block.call })
  end
end

def current_timestamp
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def log_task_duration(task_description, &task)
  task_start = current_timestamp
  task.call
  STDERR.puts "Done '#{task_description}' : #{(current_timestamp - task_start).round(2)} secs"
  STDERR.puts
end

def geolite_dbs
  @geolite_dbs ||= %w{
    GeoLite2-City
    GeoLite2-ASN
  }
end

def get_mmdb_time(root_path)
  mmdb_time = nil

  geolite_dbs.each do |name|
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

  geolite_dbs.each do |name|
    from = File.join(from_path, "#{name}.mmdb")
    to = File.join(to_path, "#{name}.mmdb")
    FileUtils.cp(from, to, preserve: true)
  end
end

def copy_ember_cli_assets
  ember_dir = "app/assets/javascripts/discourse"
  ember_cli_assets = "#{ember_dir}/dist/assets/"
  assets = {}
  files = {}

  log_task_duration('ember build -prod') {
    unless system("yarn --cwd #{ember_dir} run ember build -prod")
      STDERR.puts "Error running ember build"
      exit 1
    end
  }

  # Copy assets and generate manifest data
  log_task_duration('Copy assets and generate manifest data') {
    Dir["#{ember_cli_assets}**/*"].each do |f|
      if File.file?(f)
        rel_file = f.sub(ember_cli_assets, "")
        file_digest = Digest::SHA384.digest(File.read(f))
        digest = if f =~ /\-([a-f0-9]+)\./
          Regexp.last_match[1]
        else
          Digest.hexencode(file_digest)[0...32]
        end

        dest = "public/assets"
        dest_sub = dest
        if rel_file =~ /^([a-z\-\_]+)\//
          dest_sub = "#{dest}/#{Regexp.last_match[1]}"
        end

        FileUtils.mkdir_p(dest_sub) unless Dir.exist?(dest_sub)
        log_file = File.basename(rel_file).sub("-#{digest}", "")

        # We need a few hacks here to move what Ember uses to what Rails wants
        case log_file
        when "discourse.js"
          log_file = "application.js"
          rel_file.sub!(/^discourse/, "application")
        when "test-support.js"
          log_file = "discourse/tests/test-support-rails.js"
          rel_file = "discourse/tests/test-support-rails-#{digest}.js"
        when "test-helpers.js"
          log_file = "discourse/tests/test-helpers-rails.js"
          rel_file = "discourse/tests/test-helpers-rails-#{digest}.js"
        end

        res = FileUtils.cp(f, "#{dest}/#{rel_file}")

        assets[log_file] = rel_file
        files[rel_file] = {
          "logical_path" => log_file,
          "mtime" => File.mtime(f).iso8601(9),
          "size" => File.size(f),
          "digest" => digest,
          "integrity" => "sha384-#{Base64.encode64(file_digest).chomp}"
        }
      end
    end
  }

  # Update manifest file
  log_task_duration('Update manifest file') {
    manifest_result = Dir["public/assets/.sprockets-manifest-*.json"]
    if manifest_result && manifest_result.size == 1
      json = JSON.parse(File.read(manifest_result[0]))
      json['files'].merge!(files)
      json['assets'].merge!(assets)
      File.write(manifest_result[0], json.to_json)
    end
  }
end

task 'test_ember_cli_copy' do
  copy_ember_cli_assets
end

task 'assets:precompile' => 'assets:precompile:before' do

  copy_ember_cli_assets if ENV['EMBER_CLI_PROD_ASSETS'] != '0'

  refresh_days = GlobalSetting.refresh_maxmind_db_during_precompile_days

  if refresh_days.to_i > 0

    mmdb_time = get_mmdb_time(DiscourseIpInfo.path)

    backup_mmdb_time =
      if GlobalSetting.maxmind_backup_path.present?
        get_mmdb_time(GlobalSetting.maxmind_backup_path)
      end

    mmdb_time ||= backup_mmdb_time
    if backup_mmdb_time && backup_mmdb_time >= mmdb_time
      copy_maxmind(GlobalSetting.maxmind_backup_path, DiscourseIpInfo.path)
      mmdb_time = backup_mmdb_time
    end

    if !mmdb_time || mmdb_time < refresh_days.days.ago
      puts "Downloading MaxMindDB..."
      mmdb_thread = Thread.new do
        begin
          geolite_dbs.each do |db|
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
    end
  end

  if $bypass_sprockets_uglify
    puts "Compressing Javascript and Generating Source Maps"
    manifest = Sprockets::Manifest.new(assets_path)

    locales = Set.new(["en"])

    RailsMultisite::ConnectionManagement.each_connection do |db|
      locales.add(SiteSetting.default_locale)
    end

    log_task_duration('Done compressing all JS files') {
      concurrent? do |proc|
        manifest.files
          .select { |k, v| k =~ /\.js$/ }
          .each do |file, info|

          path = "#{assets_path}/#{file}"
            _file = (d = File.dirname(file)) == "." ? "_#{file}" : "#{d}/_#{File.basename(file)}"
            _path = "#{assets_path}/#{_file}"
            max_compress = max_compress?(info["logical_path"], locales)
            if File.exist?(_path)
              STDERR.puts "Skipping: #{file} already compressed"
            elsif file.include? "discourse/tests"
              STDERR.puts "Skipping: #{file}"
            else
              proc.call do
                log_task_duration(file) {
                  STDERR.puts "Compressing: #{file}"

                  if max_compress
                    FileUtils.mv(path, _path)
                    compress(_file, file)
                  end

                  info["size"] = File.size(path)
                  info["mtime"] = File.mtime(path).iso8601
                  gzip(path)
                  brotli(path, max_compress)
                }
              end
            end
        end
      end
    }

    # protected
    manifest.send :save

    if GlobalSetting.fallback_assets_path.present?
      begin
        FileUtils.cp_r("#{Rails.root}/public/assets/.", GlobalSetting.fallback_assets_path)
      rescue => e
        STDERR.puts "Failed to backup assets to #{GlobalSetting.fallback_assets_path}"
        STDERR.puts e
        STDERR.puts e.backtrace
      end
    end
  end

  mmdb_thread.join if mmdb_thread
end

Rake::Task["assets:precompile"].enhance do
  class Sprockets::Manifest
    def reload
      @filename = find_directory_manifest(@directory)
      @data = json_decode(File.read(@filename))
    end
  end

  # cause on boot we loaded a blank manifest,
  # we need to know where all the assets are to precompile CSS
  # cause CSS uses asset_path
  Rails.application.assets_manifest.reload
  Rake::Task["assets:precompile:css"].invoke
end
