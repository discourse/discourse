# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

class SystemPersistentBrowser
  SAFE_CONTEXT_METHODS = %i[
    add_cookies
    background_pages
    browser
    clear_cookies
    clear_permissions
    closed?
    cookies
    grant_permissions
    new_page
    pages
    service_workers
    storage_state
    tracing
  ].freeze
  private_constant :SAFE_CONTEXT_METHODS

  def self.statistics
    counters.dup
  end

  def self.record(name)
    counters[name] += 1
  end

  def self.counters
    if @statistics_pid != Process.pid
      @statistics_pid = Process.pid
      @statistics = {
        persistent_contexts: 0,
        native_contexts: 0,
        additional_contexts: 0,
        reused_resets: 0,
        full_resets: 0,
        reset_errors: 0,
      }
    end
    @statistics
  end
  private_class_method :counters

  def initialize(options)
    @options = options
    @launch_options = Capybara::Playwright::BrowserOptions.new(options).value
  end

  def start
    self
  end

  def new_context(**options)
    close if @context&.closed? || (@browser && !@browser.connected?)
    if @context
      invalidate_context
      context = @browser.new_context(**options)
      self.class.record(:additional_contexts)
      return context
    end
    @execution ||=
      Playwright.create(
        playwright_cli_executable_path: @options.fetch(:playwright_cli_executable_path),
      )

    if options[:storageState] || options[:record_video_dir] || options[:record_har_path] ||
         options[:httpCredentials] || options[:permissions]&.any? ||
         options[:serviceWorkers] == "allow"
      @browser ||= @execution.playwright.chromium.launch(**@launch_options)
      @context = @browser.new_context(**options)
      @persistent = false
      self.class.record(:native_contexts)
    else
      @profile = Dir.mktmpdir("discourse-system-browser-")
      launch_options = @launch_options.merge(args: Array(@launch_options[:args]).dup)
      disabled =
        launch_options[:args]
          .filter_map do |argument|
            argument.split("=", 2).last if argument.start_with?("--disable-features=")
          end
          .flat_map { |value| value.split(",") }
      launch_options[:args].reject! { |argument| argument.start_with?("--disable-features=") }
      launch_options[
        :args
      ] << "--disable-features=#{(disabled + ["ScriptStreaming"]).uniq.join(",")}"
      @context =
        @execution.playwright.chromium.launch_persistent_context(
          @profile,
          **launch_options,
          **options,
        )
      @browser = @context.browser
      @context.pages.each(&:close)
      @persistent = true
      self.class.record(:persistent_contexts)
      @context.on("page", ->(page) { page.on("download", ->(_download) { invalidate_context }) })
    end
    @context_changed = false
    @context
  rescue StandardError
    begin
      close
    rescue StandardError
      nil
    end
    raise
  end

  def contexts
    @browser&.contexts || []
  end

  def browser_type
    @browser.browser_type
  end

  def reusable_context?
    @persistent && !@context_changed && @context && !@context.closed? && @browser.connected?
  end

  def invalidate_context
    @context_changed = true
  end

  def monitor_context
    return if !@persistent || @monitored_context == @context

    owner = self
    monitor = Module.new
    (
      Playwright::BrowserContext.public_instance_methods(false) - SAFE_CONTEXT_METHODS
    ).each do |method_name|
      monitor.define_method(method_name) do |*args, **options, &block|
        owner.invalidate_context
        owner.close_other_contexts if method_name == :close
        super(*args, **options, &block)
      end
    end
    @context.singleton_class.prepend(monitor)
    @monitored_context = @context
  end

  def reset
    previous_context = @context if @context && !@context.closed? && @browser.connected?
    completed = false
    result = yield
    completed = true
    result
  ensure
    if previous_context
      counter =
        if !completed
          :reset_errors
        elsif previous_context == @context && !previous_context.closed? && @browser&.connected?
          :reused_resets
        else
          :full_resets
        end
      self.class.record(counter)
    end
  end

  def close_other_contexts
    contexts.each { |context| context.close unless context == @context }
  end

  def close
    error = nil
    begin
      @browser&.close
    rescue StandardError => failure
      error = failure
    ensure
      begin
        @execution&.stop
      rescue StandardError => failure
        error ||= failure
      ensure
        @browser = @context = @execution = @monitored_context = nil
        begin
          FileUtils.remove_entry(@profile) if @profile && File.directory?(@profile)
          @profile = nil
        rescue StandardError => failure
          error ||= failure
        end
      end
    end
    raise error if error
  end

  alias stop close
end

RSpec.configure do |config|
  config.after(:suite) do
    if ENV["DISCOURSE_SYSTEM_BROWSER_CACHE"] == "1"
      number = ENV.fetch("TEST_ENV_NUMBER", "")
      worker =
        if number.empty?
          1
        elsif number.match?(/\A[1-9][0-9]?\z/) && number.to_i <= 64
          number.to_i
        else
          "other"
        end
      puts "SYSTEM_BROWSER_CACHE #{JSON.generate(SystemPersistentBrowser.statistics.merge(worker: worker))}"
    end
  end
end

class SystemPersistentDriver < Capybara::Playwright::Driver
  def initialize(app, **options)
    super
    @browser_runner = SystemPersistentBrowser.new(options)
  end

  def reset!
    @browser_runner.reset { super }
  end

  private

  def browser
    super.tap { @browser_runner.monitor_context }
  end
end
