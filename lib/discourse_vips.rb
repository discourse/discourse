# frozen_string_literal: true

require "erb"
require "json"
require "socket"

require_relative "freedom_patches/landlock_capture_fork"

module DiscourseVips
  VERSION = 1
  DEFAULT_TIMEOUT_SECONDS = 5
  CLIENT_TIMEOUT_SECONDS = 7
  FONT_FAMILIES = {
    "/System/Library/Fonts/Helvetica.ttc" => "Helvetica",
    File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2") => "Noto Sans",
  }.freeze
  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
  DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  RLIMITS = {
    cpu_seconds: 5,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze
  private_constant :DEFAULT_TIMEOUT_SECONDS,
                   :CLIENT_TIMEOUT_SECONDS,
                   :FONT_FAMILIES,
                   :FONTCONFIG_READ_PATHS,
                   :DYNAMIC_LINKER_CACHE_PATH,
                   :RLIMITS

  class Error < RuntimeError
  end

  class << self
    def version(expected_broker_pid: nil)
      "#{VERSION}-#{request(operation: "version", expected_broker_pid:)}"
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
      )
      nil
    end

    def socket_path
      ENV["DISCOURSE_VIPS_SOCKET_PATH"] || Rails.root.join("tmp/discourse-vips.sock").to_s
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

    def request(operation:, arguments: {}, expected_broker_pid: nil)
      ensure_sandbox_available!

      UNIXSocket.open(socket_path) do |socket|
        socket.puts(JSON.generate(operation:, arguments:))
        socket.close_write
        readable, = IO.select([socket], nil, nil, CLIENT_TIMEOUT_SECONDS)
        raise Error, "libvips broker did not respond" if !readable

        payload = socket.gets
        raise Error, "libvips broker closed the connection" if !payload

        response = JSON.parse(payload)
        if expected_broker_pid && response["broker_pid"] != expected_broker_pid
          raise Error, "libvips broker identity did not match"
        end
        return response["value"] if response["status"] == "ok"
        raise Error, "libvips operation timed out" if response["status"] == "timeout"

        raise Error, response["message"].presence || "libvips operation failed"
      end
    rescue IOError, SystemCallError => error
      raise Error, "libvips broker request failed: #{error.message}"
    rescue JSON::ParserError => error
      raise Error, "libvips broker returned an invalid response: #{error.message}"
    end

    def ensure_sandbox_available!
      if !Rails.env.local? && !Discourse::SafeExec.landlock_supported?
        raise Error, "Cannot run libvips because Landlock sandboxing is unavailable"
      end
    end
  end
end
