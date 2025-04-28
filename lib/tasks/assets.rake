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

    compile_command = "#{Rails.root}/script/assemble_ember_build.rb"

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
  require "open3"

  # Ensure we ALWAYS do a clean build
  # We use many .erbs that get out of date quickly, especially with plugins
  STDERR.puts "Purging temp files"
  `rm -fr #{Rails.root}/tmp/cache`

  Rails.configuration.assets.js_compressor = nil
  Rails.configuration.assets.gzip = false

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

def gzip(path)
  STDERR.puts "gzip -f -c -9 #{path} > #{path}.gz"
  STDERR.puts `gzip -f -c -9 #{path} > #{path}.gz`.strip
  raise "gzip compression failed: exit code #{$?.exitstatus}" if $?.exitstatus != 0
end

def brotli_command(path)
  compression_quality = ENV["DISCOURSE_ASSETS_PRECOMPILE_DEFAULT_BROTLI_QUALITY"] || "6"
  "brotli -f --quality=#{compression_quality} #{path} --output=#{path}.br"
end

def brotli(path)
  STDERR.puts brotli_command(path)
  STDERR.puts `#{brotli_command(path)}`
  raise "brotli compression failed: exit code #{$?.exitstatus}" if $?.exitstatus != 0
  STDERR.puts `chmod +r #{path}.br`.strip
  raise "chmod failed: exit code #{$?.exitstatus}" if $?.exitstatus != 0
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
            if file.include? "discourse/tests"
              STDERR.puts "Skipping: #{file}"
            else
              proc.call do
                log_task_duration(file) do
                  STDERR.puts "Compressing: #{file}"

                  info["size"] = File.size(path)
                  info["mtime"] = File.mtime(path).iso8601
                  gzip(path)
                  brotli(path)
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
