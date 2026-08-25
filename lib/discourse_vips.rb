# frozen_string_literal: true

require "mini_vips"
require "tmpdir"

module DiscourseVips
  DEFAULT_TIMEOUT_SECONDS = 5
  private_constant :DEFAULT_TIMEOUT_SECONDS

  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
  private_constant :FONTCONFIG_READ_PATHS

  DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  private_constant :DYNAMIC_LINKER_CACHE_PATH

  RLIMITS = {
    cpu_seconds: 5,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze
  private_constant :RLIMITS

  class Error < RuntimeError
  end

  class << self
    def version
      "#{MiniVips::VERSION}-#{run(command: "version").strip}"
    end

    def generate_letter_avatar(letter:, background_color:, output_path:)
      red, green, blue = validate_background_color(background_color)
      run(
        command: "letter-avatar",
        arguments: [
          letter.to_s,
          output_path,
          "--background-color",
          format("%02X%02X%02X", red, green, blue),
        ],
        read: [bundled_font_path, *FONTCONFIG_READ_PATHS],
        write: [File.dirname(output_path)],
      )
      nil
    end

    def resize_letter_avatar(input_path:, output_path:, size:)
      run(
        command: "resize",
        arguments: [
          input_path,
          output_path,
          "--width",
          size.to_s,
          "--height",
          size.to_s,
          "--fit",
          "cover",
          "--quality",
          "100",
          "--colors",
          "256",
          "--strip-metadata",
        ],
        read: [input_path],
        write: [File.dirname(output_path)],
      )
      nil
    end

    def dominant_color(input_path:)
      run(command: "dominant-color", arguments: [input_path], read: [input_path]).strip
    end

    def generate_topic_og_image(svg_path:, output_path:, max_pixels:)
      run(
        command: "convert",
        arguments: [svg_path, output_path, "--max-pixels", max_pixels.to_s],
        read: [File.dirname(svg_path), *FONTCONFIG_READ_PATHS],
        write: [File.dirname(output_path)],
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

    def run(command:, arguments: [], read: [], write: [])
      Dir.mktmpdir("discourse-vips-helper-") do |scratch|
        argv = ["nice", "-n", "10", executable, command, *arguments]

        begin
          Discourse::SafeExec.capture(
            *argv,
            env: environment(scratch),
            unsetenv_others: true,
            read: read_paths(read),
            write: [scratch, *write],
            execute: [*Discourse::SafeExec.default_execute_paths, executable],
            timeout: DEFAULT_TIMEOUT_SECONDS,
            rlimits: RLIMITS,
            seccomp_deny_network: true,
          )
        rescue Discourse::Utils::CommandError => error
          raise Error, error.message
        end
      end
    end

    def executable
      @executable ||= MiniVips.executable
    end

    def bundled_font_path
      File.join(File.dirname(File.dirname(executable)), "lib/mini_vips/fonts/NotoSans-Regular.ttf")
    end

    def environment(scratch)
      {
        **ENV.to_h.slice("PATH", "LANG", "LC_ALL"),
        "TMPDIR" => scratch,
        "HOME" => scratch,
        "XDG_CACHE_HOME" => scratch,
        "MALLOC_ARENA_MAX" => "2",
      }
    end

    def read_paths(paths)
      Discourse::SafeExec.existing_paths(
        [
          *Discourse::SafeExec.default_read_paths,
          DYNAMIC_LINKER_CACHE_PATH,
          executable,
          *paths.compact,
        ],
      )
    end
  end
end
