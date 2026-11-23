# frozen_string_literal: true

require "fileutils"
require "json"
require "zlib"
require "timeout"
require "digest"

class SystemCoverage
  class << self
    attr_accessor :current
  end

  def initialize(id)
    @id = id
    @directory = ENV.fetch("SYSTEM_COVERAGE_DIRECTORY")
    @worker = ENV.fetch("TEST_ENV_NUMBER", "0")
    @collect_css = ENV.fetch("SYSTEM_CSS_COVERAGE", "0") == "1"
    @pages = {}
  end

  def start_page(page, late: false)
    return if @pages.key?(page.guid)

    @pages[page.guid] = SystemPageCoverage.new(
      id: @id,
      page: page,
      directory: @directory,
      worker: @worker,
      late: late,
    )
    @pages.fetch(page.guid).start
  rescue StandardError => error
    record_error(error)
  end

  def capture(page)
    @pages.delete(page.guid)&.finish
  rescue StandardError => error
    record_error(error)
  end

  def preserve_stylesheet(response)
    return unless @collect_css && response.status == 200
    preserve_stylesheet_url(response.url)
  end

  def preserve_stylesheet_url(url)
    return unless @collect_css
    # Chromium includes the document fragment in some stylesheet notifications.
    path = url[%r{\A(?:[a-z][a-z0-9+.-]*:)?(?://[^/?#]*)?(/[^?#]*)}i, 1]
    return unless path&.include?("/stylesheets/") && path.end_with?(".css")
    return if File.file?(File.join(@directory, "stylesheets-#{@worker}", File.basename(path)))
    cached = File.join(Stylesheet::Manager.cache_fullpath, File.basename(path))
    archive_stylesheet(path: path, source: File.read(cached), required: false) if File.file?(cached)
  end

  def finish
    @pages.values.each do |page|
      page.finish
    rescue StandardError => error
      record_error(error)
    end
    @pages.clear
  end

  private

  def record_error(error)
    File.open(File.join(@directory, "browser-errors-#{Process.pid}.log"), "a") do |file|
      file.puts("#{error.class}: #{error.message}")
    end
  end

  def archive_stylesheet(path:, source:, required:)
    annotation =
      source.b.byteslice([source.bytesize - 1024, 0].max, 1024)[/sourceMappingURL=([^\s*]+)/, 1]
    return unless annotation

    filename = File.basename(path)
    map = File.basename(annotation.split("?").first)
    directory = File.join(@directory, "stylesheets-#{@worker}")
    archived_map = File.join(directory, map)
    unless File.file?(archived_map)
      cached_map = File.join(Stylesheet::Manager.cache_fullpath, map)
      unless File.file?(cached_map)
        raise "Missing stylesheet map: #{cached_map}" if required
        return
      end
      FileUtils.mkdir_p(directory)
      FileUtils.cp(cached_map, archived_map)
    end
    output = File.join(directory, filename)
    File.binwrite(output, source) unless File.file?(output)
    [filename, map]
  end
end

class SystemPageCoverage
  def initialize(id:, page:, directory:, worker:, late:)
    @id = id
    @page = page
    @directory = directory
    @worker = worker
    @late = late
    @javascript = ENV.fetch("SYSTEM_JS_COVERAGE", "1") == "1"
    @css = ENV.fetch("SYSTEM_CSS_COVERAGE", "0") == "1"
    @session = Playwright::PlaywrightApi.unwrap(page.context.new_cdp_session(page))
    @writer = Mutex.new
    @buffer = []
    @navigation_requests = Queue.new
    @saw_script = false
    @saw_stylesheet = false
    @sequence = 0
  end

  def start
    if @javascript
      @session.on(
        "Debugger.scriptParsed",
        lambda do |event|
          next unless application_script?(event.fetch("url"))
          @saw_script = true
          write_metadata(
            "scripts",
            script_id: event.fetch("scriptId"),
            url: event.fetch("url"),
            source_map_url: event["sourceMapURL"],
          )
        end,
      )
    end
    command("Debugger.enable", maxScriptsCacheSize: 0) if @javascript || @css
    if @javascript
      command("Profiler.enable")
      command(
        "Profiler.startPreciseCoverage",
        callCount: false,
        detailed: true,
        allowTriggeredUpdates: false,
      )
    end
    if @css
      @session.on(
        "CSS.styleSheetAdded",
        lambda do |event|
          header = event.fetch("header")
          @saw_stylesheet = true
          write_metadata(
            "styles",
            style_sheet_id: header.fetch("styleSheetId"),
            url: header.fetch("sourceURL"),
            source_map_url: header["sourceMapURL"],
          )
          SystemCoverage.current&.preserve_stylesheet_url(header.fetch("sourceURL"))
        end,
      )
      command("DOM.enable")
      command("CSS.enable")
      command("CSS.startRuleUsageTracking")
    end
    @session.on(
      "Debugger.paused",
      lambda do |event|
        if event.fetch("callFrames").first&.fetch("functionName") == "systemCoverageBeforeUnload"
          @navigation_requests << event
        end
      end,
    )
    @navigation_worker =
      Thread.new do
        loop do
          event = @navigation_requests.pop
          break if event == :stop
          begin
            Timeout.timeout(15) do
              if @saw_script
                save_javascript(command("Profiler.takePreciseCoverage"), phase: "js_navigation")
              end
              if @saw_stylesheet
                save_css(
                  command("CSS.takeCoverageDelta").fetch("coverage"),
                  phase: "css_navigation",
                )
              end
            end
          rescue StandardError => error
            @navigation_error = error
          ensure
            command("Debugger.resume")
          end
        end
      rescue StandardError => error
        @navigation_error = error
      end
    source = <<~JAVASCRIPT
      (() => {
        const key = Symbol.for("systemCoverageBeforeUnload");
        if (window[key]) removeEventListener("beforeunload", window[key]);
        window[key] = function systemCoverageBeforeUnload() { debugger; };
        addEventListener("beforeunload", window[key]);
      })();
    JAVASCRIPT
    command("Page.enable")
    @navigation_script =
      command("Page.addScriptToEvaluateOnNewDocument", source: source, runImmediately: true).fetch(
        "identifier",
      )
    write_metadata(
      "lifecycle",
      event: "start",
      frame_goto_owner: @page.main_frame.method(:goto).owner.to_s,
      frame_goto_ancestors: @page.main_frame.class.ancestors.map(&:to_s),
      javascript: @javascript,
      css: @css,
    )
  end

  def finish
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    command("Page.removeScriptToEvaluateOnNewDocument", identifier: @navigation_script)
    @navigation_requests << :stop
    @navigation_worker&.join
    begin
      save_javascript(command("Profiler.takePreciseCoverage"), phase: "js_end") if @javascript
      save_css(command("CSS.stopRuleUsageTracking").fetch("ruleUsage"), phase: "css_end") if @css
    ensure
      if @javascript
        command("Profiler.stopPreciseCoverage")
        command("Profiler.disable")
      end
      command("Debugger.disable") if @javascript || @css
      command("CSS.disable") if @css
      @session.detach
    end
    raise @navigation_error if @navigation_error
    write_metadata(
      "lifecycle",
      event: "finish",
      url: location(@page.url),
      cleanup_wall_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
    )
  ensure
    flush_records
  end

  private

  def command(method, **parameters)
    write_metadata("commands", method: method, parameters: parameters)
    @session.send_message(method, params: parameters)
  end

  def save_javascript(event, phase:)
    entries = event.fetch("result").select { |entry| application_script?(entry.fetch("url")) }
    write_coverage(
      phase: phase,
      javascript_entries: entries,
      css_rule_usage: [],
      occasion: event["occasion"],
    )
  end

  def application_script?(url)
    url.include?("/assets/js/") || url.match?(%r{/assets/chunk\.[^/?#]+\.js(?:[?#]|\z)})
  end

  def save_css(rules, phase:)
    write_coverage(
      phase: phase,
      javascript_entries: [],
      css_rule_usage: rules.select { |rule| rule.fetch("used") },
    )
  end

  def write_coverage(**record)
    @writer.synchronize do
      @sequence += 1
      @buffer << [
        "coverage",
        record.merge(
          id: @id,
          page: @page.guid,
          worker: @worker,
          sequence: @sequence,
          url: location(@page.url),
          loaded_assets_only: @late,
        ),
      ]
    end
  end

  def write_metadata(name, **record)
    @writer.synchronize do
      @buffer << [
        name,
        record.merge(
          id: @id,
          page: @page.guid,
          at: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        ),
      ]
    end
  end

  def flush_records
    @buffer
      .group_by(&:first)
      .each do |name, records|
        if name == "coverage"
          payload = records.map { |_, record| JSON.generate(record) }.join("\n") + "\n"
          compressed = Zlib.gzip(payload, level: Zlib::BEST_SPEED)
          example = Digest::SHA256.hexdigest(@id)[0, 16]
          path = File.join(@directory, "browser-#{Process.pid}-#{@page.guid}-#{example}.jsonl.gz")
          temporary = File.join(@directory, ".#{File.basename(path)}.partial")
          File.binwrite(temporary, compressed)
          File.rename(temporary, path)
        else
          File.open(
            File.join(@directory, "#{name}-#{Process.pid}-#{@page.guid}.jsonl"),
            "ab",
          ) { |file| records.each { |_, record| file.puts(JSON.generate(record)) } }
        end
      end
    @buffer.clear
  end

  def location(url)
    url[/\A[^?#]*/]
  end
end

module SystemCoveragePageLifecycle
  def close(...)
    SystemCoverage.current&.capture(self)
    super
  end
end

module SystemCoverageContextLifecycle
  def new_page(...)
    super.tap { |page| SystemCoverage.current&.start_page(page) }
  end

  def close(...)
    if collector = SystemCoverage.current
      pages.each { |page| collector.capture(page) }
    end
    super
  end
end

module SystemCoverageBrowserLifecycle
  def new_context(...)
    super.tap do |context|
      context.on("response", ->(response) { SystemCoverage.current&.preserve_stylesheet(response) })
    end
  end

  def close(...)
    if collector = SystemCoverage.current
      contexts.each { |context| context.pages.each { |page| collector.capture(page) } }
    end
    super
  end
end

Playwright::Page.prepend(SystemCoveragePageLifecycle)
Playwright::BrowserContext.prepend(SystemCoverageContextLifecycle)
Playwright::Browser.prepend(SystemCoverageBrowserLifecycle)

module SystemCoverageWindowLifecycle
  private

  def on_window(handle)
    super do |page|
      SystemCoverage.current&.start_page(page, late: true)
      yield(page)
    end
  end
end

Capybara::Playwright::Browser.prepend(SystemCoverageWindowLifecycle)

RSpec.configure do |config|
  config.before(:each, type: :system) do |example|
    collector = SystemCoverage.current = SystemCoverage.new(example.id)
    page.driver.with_playwright_page { |browser_page| collector.start_page(browser_page) }
  end

  config.after(:each, type: :system) do
    SystemCoverage.current&.finish
  ensure
    SystemCoverage.current = nil
  end
end
