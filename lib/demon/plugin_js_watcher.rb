# frozen_string_literal: true

class Demon::PluginJsWatcher < ::Demon::Base
  def self.prefix
    "plugin_js_watcher"
  end

  def after_fork
    log("[PluginJsWatcher] Loading PluginJsWatcher in process id #{Process.pid}")

    @queue = Queue.new

    trap("INT") { @queue.push(:stop) }
    trap("TERM") { @queue.push(:stop) }
    trap("HUP") { @queue.push(:stop) }

    Plugin::JsManager.new.watch { @queue.pop }
  ensure
    STDERR.puts "Finished Plugin JS watcher thread" 
  end

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def stop_signal
    "TERM"
  end
end
