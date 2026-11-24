# frozen_string_literal: true

require "fileutils"
require "tmpdir"

class DiscourseBiDiBrowser
  def self.executable
    return ENV["FIREFOX_PATH"] if ENV["FIREFOX_PATH"].present?

    macos_path = "/Applications/Firefox.app/Contents/MacOS/firefox"
    RUBY_PLATFORM.include?("darwin") && File.executable?(macos_path) ? macos_path : "firefox"
  end

  def initialize(headless:, mobile:, &on_event)
    @headless = headless
    @mobile = mobile
    @on_event = on_event
  end

  def start
    return @client if @client

    remote = ENV["BIDI_BROWSER_URL"].presence
    socket = remote || launch_firefox
    @client = BrowserWebSocket.new(socket, &@on_event)
    unless remote
      @client.command("session.new", { capabilities: { alwaysMatch: { browserName: "firefox" } } })
    end
    @client
  rescue StandardError
    close
    raise
  end

  def close
    @client&.close
    @client = nil
    if @pid
      begin
        Process.kill("TERM", -@pid)
      rescue Errno::ESRCH
        nil
      ensure
        Process.waitpid(@pid)
        @pid = nil
      end
    end
  ensure
    FileUtils.remove_entry(@directory) if @directory && File.directory?(@directory)
    @directory = nil
  end

  private

  def launch_firefox
    executable = self.class.executable
    @directory = Dir.mktmpdir("discourse-firefox-")
    profile = File.join(@directory, "profile")
    FileUtils.mkdir_p(profile)
    preferences = <<~JS
      // Parallel test profiles share the runner's disk.
      user_pref("browser.cache.disk.smart_size.enabled", false);
      user_pref("browser.cache.disk.capacity", 65536);
      user_pref("browser.shell.checkDefaultBrowser", false);
      user_pref("browser.startup.homepage_override.mstone", "ignore");
      user_pref("browser.startup.page", 0);
    JS
    if @mobile
      preferences += <<~JS
        user_pref("dom.w3c_touch_events.enabled", 1);
        user_pref("ui.primaryPointerCapabilities", 1);
        user_pref("ui.allPointerCapabilities", 1);
      JS
    elsif @headless
      preferences += <<~JS
        user_pref("ui.primaryPointerCapabilities", 6);
        user_pref("ui.allPointerCapabilities", 6);
      JS
    end
    File.write(File.join(profile, "user.js"), preferences)
    args = [executable, "--no-remote", "--profile", profile, "--remote-debugging-port", "0"]
    args << "--headless" if @headless
    args << "about:blank"
    log = File.join(@directory, "browser.log")
    @pid = Process.spawn(*args, in: File::NULL, out: log, err: log, pgroup: true)
    "#{wait_for_endpoint(log)}/session"
  rescue Errno::ENOENT
    raise SystemBrowserError, "Firefox is unavailable. Set FIREFOX_PATH to its executable."
  end

  def wait_for_endpoint(log)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    loop do
      contents = File.exist?(log) ? File.read(log) : ""
      if (endpoint = contents[%r{WebDriver BiDi listening on (ws://[^\s]+)}, 1])
        return endpoint
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise SystemBrowserTimeout, "Firefox did not start: #{contents}"
      end
      sleep 0.05
    end
  end
end
