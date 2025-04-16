# frozen_string_literal: true

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

task "assets:precompile:before": %w[environment assets:precompile:build]

task "assets:precompile:css" => "environment" do
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

def gzip(path)
  cmd = "gzip -f -c -9 #{path} > #{path}.gz"
  system cmd, exception: true
end

def brotli_command(path)
  compression_quality = ENV["DISCOURSE_ASSETS_PRECOMPILE_DEFAULT_BROTLI_QUALITY"] || "6"
  "brotli -f --quality=#{compression_quality} #{path} --output=#{path}.br"
end

def brotli(path)
  system brotli_command(path), exception: true
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
  puts "Compressing JavaScript files"

  load_path = Rails.application.assets.load_path

  log_task_duration("Done compressing all JS files") do
    concurrent? do |proc|
      load_path
        .assets
        .select { |asset| asset.logical_path.extname == ".js" }
        .each do |asset|
          digested_path = asset.digested_path.to_s

          if digested_path.include? "discourse/tests"
            STDERR.puts "Skipping: #{digested_path}"
            next
          end

          proc.call do
            log_task_duration(digested_path) do
              STDERR.puts "Compressing: #{digested_path}"
              file_path = "public/assets/#{digested_path}"
              gzip(file_path)
              brotli(file_path)
            end
          end
        end
    end
  end

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
