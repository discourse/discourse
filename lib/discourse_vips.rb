# frozen_string_literal: true

require "erb"
require "fileutils"
require "image_processing/instrumentation"
require "json"
require "rbconfig"
require "socket"

require_relative "freedom_patches/landlock_capture_fork"

module DiscourseVips
  VERSION = 1
  DEFAULT_CLIENT_TIMEOUT_SECONDS = 7
  private_constant :DEFAULT_CLIENT_TIMEOUT_SECONDS

  TOPIC_OG_CLIENT_TIMEOUT_SECONDS = 22
  private_constant :TOPIC_OG_CLIENT_TIMEOUT_SECONDS

  BROKER_CHECK_TIMEOUT_SECONDS = 1
  private_constant :BROKER_CHECK_TIMEOUT_SECONDS

  BROKER_START_TIMEOUT_SECONDS = 5
  private_constant :BROKER_START_TIMEOUT_SECONDS

  INSTRUMENTED_OPERATIONS = {
    "generate_letter_avatar" => :letter_avatar_render,
    "resize_letter_avatar" => :optimized_image_resize,
    "dominant_color" => :upload_dominant_color,
    "svg_to_png" => :topic_og_render,
  }.freeze
  private_constant :INSTRUMENTED_OPERATIONS

  FONT_FAMILIES = {
    "/System/Library/Fonts/Helvetica.ttc" => "Helvetica",
    File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2") => "Noto Sans",
  }.freeze
  private_constant :FONT_FAMILIES

  class Error < RuntimeError
  end

  class BrokerUnavailable < Error
  end
  private_constant :BrokerUnavailable

  class << self
    def socket_path
      ENV["DISCOURSE_VIPS_SOCKET_PATH"] || File.expand_path("../tmp/discourse-vips.sock", __dir__)
    end

    def start
      ensure_sandbox_available!
      FileUtils.mkdir_p(File.dirname(socket_path))

      File.open(startup_lock_path, File::CREAT | File::RDWR, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        broker_pid = running_broker_pid
        return broker_pid if broker_pid

        FileUtils.rm_f(socket_path)
        broker_pid = spawn_broker
        wait_until_ready(broker_pid)
        broker_pid
      end
    end

    def version
      "#{VERSION}-#{request(operation: "version")}"
    end

    def generate_letter_avatar(letter:, background_color:, font_path:, output_path:)
      font_path = File.expand_path(font_path.to_s)
      font_family = FONT_FAMILIES[font_path]
      if !File.file?(font_path) || !font_family
        raise ArgumentError, "font_path must reference a supported font file"
      end

      request(
        operation: "generate_letter_avatar",
        arguments: {
          markup:
            %(<span foreground="#ffffff" alpha="80%">#{ERB::Util.html_escape(letter.to_s)}</span>),
          font: "#{font_family} 280",
          font_path:,
          background_color: validate_background_color(background_color),
          output_path: File.expand_path(output_path),
        },
      )
      nil
    end

    def resize_letter_avatar(input_path:, output_path:, size:)
      request(
        operation: "resize_letter_avatar",
        arguments: {
          input_path: File.expand_path(input_path),
          output_path: File.expand_path(output_path),
          size:,
        },
      )
      nil
    end

    def dominant_color(input_path:)
      request(operation: "dominant_color", arguments: { input_path: File.expand_path(input_path) })
    end

    def generate_topic_og_image(svg_path:, output_path:)
      request(
        operation: "svg_to_png",
        arguments: {
          input_path: File.expand_path(svg_path),
          output_path: File.expand_path(output_path),
        },
        timeout: TOPIC_OG_CLIENT_TIMEOUT_SECONDS,
      )
      nil
    end

    private

    def validate_background_color(background_color)
      channels = Array(background_color)
      if channels.length != 3 ||
           channels.any? { |channel| !channel.is_a?(Integer) || !(0..255).cover?(channel) }
        raise ArgumentError, "background_color must contain three channels in 0..255"
      end
      channels
    end

    def request(operation:, arguments: {}, timeout: DEFAULT_CLIENT_TIMEOUT_SECONDS)
      instrumentation_operation = INSTRUMENTED_OPERATIONS[operation]
      return request_with_broker(operation:, arguments:, timeout:) if !instrumentation_operation

      ImageProcessing::Instrumentation.instrument(operation: instrumentation_operation) do
        request_with_broker(operation:, arguments:, timeout:)
      end
    end

    def request_with_broker(operation:, arguments:, timeout:)
      perform_request(operation:, arguments:, timeout:)
    rescue BrokerUnavailable
      start
      perform_request(operation:, arguments:, timeout:)
    end

    def perform_request(operation:, arguments:, timeout:)
      ensure_sandbox_available!
      response = exchange_request(operation:, arguments:, timeout:)

      return response["value"] if response["status"] == "ok"
      raise Error, "libvips operation timed out" if response["status"] == "timeout"

      raise Error, response["message"].presence || "libvips operation failed"
    end

    def exchange_request(operation:, arguments:, timeout:)
      UNIXSocket.open(socket_path) do |socket|
        socket.puts(JSON.generate(operation:, arguments:))
        socket.close_write
        readable, = IO.select([socket], nil, nil, timeout)
        raise Error, "libvips broker did not respond" if !readable

        payload = socket.gets
        raise BrokerUnavailable, "libvips broker closed the connection" if !payload

        JSON.parse(payload)
      end
    rescue IOError, SystemCallError => error
      raise BrokerUnavailable, "libvips broker request failed: #{error.message}"
    rescue JSON::ParserError => error
      raise Error, "libvips broker returned an invalid response: #{error.message}"
    end

    def startup_lock_path
      "#{socket_path}.lock"
    end

    def running_broker_pid
      response =
        exchange_request(operation: "version", arguments: {}, timeout: BROKER_CHECK_TIMEOUT_SECONDS)
      response["broker_pid"] if response["status"] == "ok"
    rescue Error
      nil
    end

    def spawn_broker
      environment = { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }
      broker_pid =
        Process.spawn(
          environment,
          RbConfig.ruby,
          Rails.root.join("script/discourse_vips_broker").to_s,
          socket_path,
          Rails.root.join("Gemfile").to_s,
          in: File::NULL,
          close_others: true,
          pgroup: true,
        )
      Process.detach(broker_pid)
      broker_pid
    end

    def wait_until_ready(expected_broker_pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + BROKER_START_TIMEOUT_SECONDS

      loop do
        return if running_broker_pid == expected_broker_pid

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          terminate_broker(expected_broker_pid)
          raise Error, "libvips broker did not start"
        end

        sleep 0.01
      end
    end

    def terminate_broker(broker_pid)
      Process.kill("TERM", broker_pid)
    rescue Errno::ESRCH
    end

    def ensure_sandbox_available!
      if !Rails.env.local? && !Discourse::SafeExec.landlock_supported?
        raise Error, "Cannot run libvips because Landlock sandboxing is unavailable"
      end
    end
  end
end
