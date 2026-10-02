# frozen_string_literal: true
require "playwright/test"

class NativeSystemBrowser
  attr_reader :page

  def self.for_example(example)
    @browsers ||= {}
    @browsers[SystemDrivers.driver_for(example)] ||= new(SystemDrivers.native_options_for(example))
  end

  def self.close_all
    @browsers&.each_value(&:close)
    @browsers = nil
  end

  def initialize(options)
    raise "Native browser does not support remote connections yet" if options[:browser] == :remote

    @execution =
      Playwright.create(
        playwright_cli_executable_path: options.fetch(:playwright_cli_executable_path),
      )
    @browser =
      @execution.playwright.chromium.launch(
        **options.slice(:channel, :headless, :downloadsPath, :slowMo, :args),
      )
    @context_options =
      options.slice(
        :acceptDownloads,
        :colorScheme,
        :deviceScaleFactor,
        :isMobile,
        :hasTouch,
        :userAgent,
        :viewport,
      ).merge(serviceWorkers: "block")
  rescue StandardError
    @execution&.stop
    raise
  end

  def start(example, base_url:)
    @example = example
    @base_url = base_url
    if @page && example.metadata[:video] && !@page.video
      @context.close
      @page = nil
    end
    create_context unless @page
    @context.default_timeout = Capybara.default_max_wait_time.to_f * 1100
    @context.default_navigation_timeout = 30_000
    if example.metadata[:trace]
      @context.tracing.start(screenshots: true, snapshots: true, sources: true)
    end
  end

  def reset
    return unless @page
    @context.tracing.stop(path: artifact_path("trace.zip")) if @example.metadata[:trace]

    video = @page.video if @example.metadata[:video]
    return if soft_reset_enabled? && soft_reset

    @browser.contexts.each(&:close)
    @page = nil
    video&.save_as(artifact_path("screenrecord.webm"))
  end

  def close
    @browser&.close
  ensure
    @execution&.stop
    if @video_directory && File.directory?(@video_directory)
      FileUtils.remove_entry(@video_directory)
    end
  end

  private

  def artifact_path(suffix)
    FileUtils.mkdir_p(Capybara.save_path)
    File.join(Capybara.save_path, "#{@example.metadata[:full_description].parameterize}-#{suffix}")
  end

  def create_context
    options = @context_options.merge(baseURL: @base_url)
    if @example.metadata[:video]
      @video_directory ||= Dir.mktmpdir("native-system-video")
      options[:record_video_dir] = @video_directory
    end
    @context = @browser.new_context(**options)
    @downloaded = false
    @context.on("download", ->(_download) { @downloaded = true })
    @page = @context.new_page
  end

  def soft_reset_enabled?
    ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] != "0" && !@example.metadata[:video]
  end

  def soft_reset
    @page =
      SystemBrowserReset.soft_reset(browser: @browser, downloaded: @downloaded) do |context|
        context.new_page
      end
    !!@page
  end
end

class SystemServerDriver < Capybara::Driver::Base
  def needs_server?
    true
  end
end

Capybara.register_driver(:native_system_server) { |_app| SystemServerDriver.new }

RSpec.configure { |config| config.after(:suite) { NativeSystemBrowser.close_all } }
