# frozen_string_literal: true

# Records each individual SQL/Redis/network call for the perf formatter. It is
# registered via MethodProfiler.register_instrumentation_callback in the test
# environment only, so production instrumentation carries no itemization logic.
module MethodProfilerItemizer
  MAX_ITEM_LENGTH = 2000
  private_constant :MAX_ITEM_LENGTH

  class << self
    def call(name, receiver, args, data, elapsed)
      item = build_item(name, receiver, args)
      return if item.nil?
      (data[:items] ||= []) << item.merge!(duration_ms: elapsed * 1000.0)
    rescue => error
      (data[:items] ||= []) << { error: truncate(utf8("#{error.class}: #{error.message}")) }
    end

    private

    def build_item(name, receiver, args)
      case name
      when :sql
        { sql: truncate(utf8(args[0])) }
      when :redis
        redis_item(args)
      when :net
        net_item(receiver, args)
      end
    end

    def redis_item(args)
      command = args[0]
      return { command: truncate(utf8(command)) } unless command.is_a?(Array)
      commands = command.first.is_a?(Array) ? command : [command]
      { command: truncate(commands.map { |entry| redis_command(entry) }.join("; ")) }
    end

    def redis_command(command)
      return utf8(command) unless command.is_a?(Array)
      [utf8(command.first).upcase, *Array(command[1..]).map { |arg| utf8(arg) }].join(" ").strip
    end

    def net_item(receiver, args)
      if defined?(Net::HTTP) && receiver.is_a?(Net::HTTP)
        request = args[0]
        url = http_url(receiver.use_ssl?, receiver.address, receiver.port, request.path)
        { method: utf8(request.method), url: truncate(utf8(url)) }
      elsif defined?(Excon::Connection) && receiver.is_a?(Excon::Connection)
        params = args[0] || {}
        data = receiver.respond_to?(:data) ? receiver.data.to_h : {}
        url =
          http_url(
            data[:scheme].to_s == "https",
            data[:host],
            data[:port],
            params[:path] || data[:path],
          )
        { method: utf8(params[:method] || data[:method]).upcase, url: truncate(utf8(url)) }
      else
        { method: "", url: "" }
      end
    end

    def http_url(ssl, host, port, path)
      scheme = ssl ? "https" : "http"
      default_port = ssl ? 443 : 80
      authority = port.nil? || port == default_port ? host : "#{host}:#{port}"
      "#{scheme}://#{authority}#{path}"
    end

    def utf8(value)
      value.to_s.dup.force_encoding(Encoding::UTF_8).scrub("?")
    end

    def truncate(string)
      return string if string.length <= MAX_ITEM_LENGTH
      "#{string[0, MAX_ITEM_LENGTH]}…(truncated, #{string.bytesize} bytes)"
    end
  end
end

if ENV["DISCOURSE_RSPEC_PERFORMANCE_FORMATTER"] == "1"
  MethodProfiler.register_instrumentation_callback(MethodProfilerItemizer)
end
