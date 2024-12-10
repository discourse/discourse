# frozen_string_literal: true

task "assets:precompile:prereqs" do
  if %w[profile production].exclude? Rails.env
    raise "rake assets:precompile should only be run in RAILS_ENV=production, you are risking unminified assets"
  end
end

task "assets:precompile:build" do
  if ENV["SKIP_EMBER_CLI_COMPILE"] != "1"
    ember_version = ENV["EMBER_VERSION"] || "5"

    raise "Unknown ember version '#{ember_version}'" if !%w[5].include?(ember_version)

    # If `JOBS` env is not set, `thread-loader` defaults to the number of CPUs - 1 on the machine but we want to cap it
    # at 2 because benchmarking has shown that anything beyond 2 does not improve build times or the increase is marginal.
    # Therefore, we cap it so that we don't spawn more processes than necessary.
    jobs_env_count = (2 if !ENV["JOBS"].present? && Etc.nprocessors > 2)

    compile_command = "CI=1 pnpm --dir=app/assets/javascripts/discourse ember build"

    heap_size_limit = check_node_heap_size_limit

    if heap_size_limit < 2048
      STDERR.puts "Node.js heap_size_limit (#{heap_size_limit}) is less than 2048MB. Setting --max-old-space-size=2048 and CHEAP_SOURCE_MAPS=1"
      jobs_env_count = 0

      compile_command =
        "CI=1 NODE_OPTIONS='--max-old-space-size=2048' CHEAP_SOURCE_MAPS=1 #{compile_command}"
    end

    ember_env = ENV["EMBER_ENV"] || "production"
    compile_command = "#{compile_command} -prod" if ember_env == "production"
    compile_command = "JOBS=#{jobs_env_count} #{compile_command}" if jobs_env_count

    only_ember_precompile_build_remaining = (ARGV.last == "assets:precompile:build")
    only_assets_precompile_remaining = (ARGV.last == "assets:precompile")

    # Using exec to free up Rails app memory during ember build
    if only_ember_precompile_build_remaining
      exec "#{compile_command}"
    elsif only_assets_precompile_remaining
      exec "#{compile_command} && SKIP_EMBER_CLI_COMPILE=1 bin/rake assets:precompile"
    else
      system compile_command, exception: true
      EmberCli.clear_cache!
    end
  end
end

task "assets:precompile:before": %w[
       environment
       assets:precompile:prereqs
       assets:precompile:build
     ] do
  require "uglifier"
  require "open3"

  # Ensure we ALWAYS do a clean build
  # We use many .erbs that get out of date quickly, especially with plugins
  STDERR.puts "Purging temp files"
  `rm -fr #{Rails.root}/tmp/cache`

  $node_compress = !ENV["SKIP_NODE_UGLIFY"]

  unless ENV["USE_SPROCKETS_UGLIFY"]
    $bypass_sprockets_uglify = true
    Rails.configuration.assets.js_compressor = nil
    Rails.configuration.assets.gzip = false
  end

  STDERR.puts "Bundling assets"

  # in the past we applied a patch that removed asset postfixes, but it is terrible practice
  # leaving very complicated build issues
  # https://github.com/rails/sprockets-rails/issues/49

  require "sprockets"
  require "digest/sha1"
end

task "assets:precompile:css" => "environment" do
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

  if ENV["DONT_PRECOMPILE_CSS"] == "1" || ENV["SKIP_DB_AND_REDIS"] == "1"
    STDERR.puts "Skipping CSS precompilation, ensure CSS lives in a shared directory across hosts"
  else
    STDERR.puts "Start compiling CSS: #{Time.zone.now}"

    RailsMultisite::ConnectionManagement.each_connection do |db|
      # CSS will get precompiled during first request if tables do not exist.
      if ActiveRecord::Base.connection.table_exists?(Theme.table_name)
        STDERR.puts "-------------"
        STDERR.puts "Compiling CSS for #{db} #{Time.zone.now}"
        begin
          Stylesheet::Manager.recalculate_fs_asset_cachebuster!
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

task "assets:flush_sw" => "environment" do
  begin
    hostname = Discourse.current_hostname
    default_port = SiteSetting.force_https? ? 443 : 80
    port = SiteSetting.port.to_i > 0 ? SiteSetting.port : default_port
    STDERR.puts "Flushing service worker script"
    `curl -s -m 1 --resolve '#{hostname}:#{port}:127.0.0.1' #{Discourse.base_url}/service-worker.js > /dev/null`
    STDERR.puts "done"
  rescue StandardError
    STDERR.puts "Warning: unable to flush service worker script"
  end
end

def check_node_heap_size_limit
  output, status =
    Open3.capture2("node", "-e", "console.log(v8.getHeapStatistics().heap_size_limit/1024/1024)")
  raise "Failed to fetch node memory limit" if status != 0
  output.to_f
end

def assets_path
  "#{Rails.root}/public/assets"
end

def global_path_klass
  @global_path_klass ||= Class.new { extend GlobalPath }
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

  cmd = <<~SH
    pnpm terser '#{assets_path}/#{from}' -m -c -o '#{to_path}' --source-map "base='#{base_source_map}',root='#{source_map_root}',url='#{source_map_url}',includeSources=true"
  SH

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

  uglified, map =
    Uglifier.new(
      comments: :none,
      source_map: {
        filename: File.basename(from),
        output_filename: File.basename(to),
      },
    ).compile_with_map(data)
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
  compression_quality =
    max_compress ? "11" : (ENV["DISCOURSE_ASSETS_PRECOMPILE_DEFAULT_BROTLI_QUALITY"] || "6")
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
  return false if EmberCli.is_ember_cli_asset?(path)
  return true if path.exclude? "locales/"

  path_locale = path.delete_prefix("locales/").delete_suffix(".js")
  return true if locales.include? path_locale

  false
end

def compress(from, to)
  $node_compress ? compress_node(from, to) : compress_ruby(from, to)
end

def concurrent?
  if ENV["SPROCKETS_CONCURRENT"] == "1"
    concurrent_compressors = []
    executor = Concurrent::FixedThreadPool.new(Concurrent.processor_count)

    yield(
      Proc.new do |&block|
        concurrent_compressors << Concurrent::Future.execute(executor: executor) { block.call }
      end
    )

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

def s3_assets_helper
  @s3_assets_helper ||= S3AssetsHelper.new
end

task "assets:precompile:compress_js": "environment" do
  if $bypass_sprockets_uglify
    puts "Compressing Javascript and Generating Source Maps"
    manifest = Sprockets::Manifest.new(assets_path)

    locales = Set.new(["en"])

    RailsMultisite::ConnectionManagement.each_connection do |db|
      locales.add(SiteSetting.default_locale)
    end

    log_task_duration("Done compressing all JS files") do
      concurrent? do |proc|
        manifest
          .files
          .select { |k, v| k =~ /\.js\z/ }
          .each do |file, info|
            path = "#{assets_path}/#{file}"

            _file =
              (
                if (d = File.dirname(file)) == "."
                  "_#{file}"
                else
                  "#{d}/_#{File.basename(file)}"
                end
              )

            _path = "#{assets_path}/#{_file}"

            max_compress = max_compress?(info["logical_path"], locales)

            if File.exist?(_path)
              STDERR.puts "Skipping: #{file} already compressed"
            elsif ENV["PRECOMPILE_SKIP_COMPRESSING_JS_ALREADY_ON_S3"] && GlobalSetting.use_s3? &&
                  s3_assets_helper.asset_on_s3?(File.join("assets", file).to_s)
              STDERR.puts "Skipping: #{file} already on S3"
            elsif file.include? "discourse/tests"
              STDERR.puts "Skipping: #{file}"
            else
              proc.call do
                log_task_duration(file) do
                  STDERR.puts "Compressing: #{file}"

                  if max_compress
                    FileUtils.mv(path, _path)
                    compress(_file, file)
                  end

                  info["size"] = File.size(path)
                  info["mtime"] = File.mtime(path).iso8601
                  gzip(path)
                  brotli(path, max_compress)
                end
              end
            end
          end
      end
    end

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
end

task "assets:precompile:theme_transpiler": "environment" do
  DiscourseJsProcessor::Transpiler.build_production_theme_transpiler
end

# Run these tasks **before** Rails' "assets:precompile" task
task "assets:precompile": %w[assets:precompile:before assets:precompile:theme_transpiler]

# Run these tasks **after** Rails' "assets:precompile" task
Rake::Task["assets:precompile"].enhance do
  Rake::Task["assets:precompile:compress_js"].invoke
  Rake::Task["assets:precompile:css"].invoke
  Rake::Task["maxminddb:refresh"].invoke
end
