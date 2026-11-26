# frozen_string_literal: true

require_relative "web_driver"

class DiscourseWebKitDriver < DiscourseWebDriver
  private

  def browser_name = "WebKitGTK"

  def browser_capabilities
    capabilities = { browserName: "MiniBrowser" }
    if (path = ENV["WEBKIT_BROWSER_PATH"].presence)
      capabilities["webkitgtk:browserOptions"] = { binary: path, args: ["--automation"] }
    end
    capabilities
  end

  def build_connection
    endpoint = ENV["WEBKIT_WEBDRIVER_URL"].presence
    environment = @headless && !endpoint ? virtual_display : {}
    WebDriverConnection.new(
      endpoint,
      executable_path: ENV.fetch("WEBKIT_WEBDRIVER_PATH", "WebKitWebDriver"),
      bind_host: "127.0.0.1",
      url_setting: "WEBKIT_WEBDRIVER_URL",
      environment:,
    )
  end

  def virtual_display
    reader, writer = IO.pipe
    @display_pid =
      Process.spawn(
        "Xvfb",
        "-displayfd",
        writer.fileno.to_s,
        "-screen",
        "0",
        "1920x1600x24",
        "-nolisten",
        "tcp",
        writer.fileno => writer,
        :in => File::NULL,
        :out => File::NULL,
        :err => File::NULL,
      )
    writer.close
    display = reader.gets&.chomp if IO.select([reader], nil, nil, 5)
    unless display&.match?(/\A\d+\z/)
      raise SystemBrowserError, "Xvfb did not start a WebKitGTK display"
    end

    { "DISPLAY" => ":#{display}", "GDK_BACKEND" => "x11" }
  rescue Errno::ENOENT
    raise SystemBrowserError, "Headless WebKitGTK requires Xvfb"
  rescue StandardError
    stop_virtual_display
    raise
  ensure
    reader&.close
    writer&.close unless writer&.closed?
  end

  def disconnect
    super
  ensure
    stop_virtual_display
  end

  def stop_virtual_display
    return unless @display_pid

    Process.kill("TERM", @display_pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    until Process.waitpid(@display_pid, Process::WNOHANG)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        Process.kill("KILL", @display_pid)
        Process.waitpid(@display_pid)
        break
      end
      sleep 0.05
    end
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  ensure
    @display_pid = nil
  end
end
