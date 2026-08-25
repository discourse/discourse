# frozen_string_literal: true

require "json"
require "landlock"
require "discourse_fonts"

require_relative "operations"

module DiscourseVips
  class Worker
    DEFAULT_READ_PATHS = %w[/bin /lib /lib64 /usr].freeze
    private_constant :DEFAULT_READ_PATHS

    FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
    private_constant :FONTCONFIG_READ_PATHS

    DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
    private_constant :DYNAMIC_LINKER_CACHE_PATH

    FONT_PATHS = [
      "/System/Library/Fonts/Helvetica.ttc",
      File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2"),
    ].freeze
    private_constant :FONT_PATHS

    ALLOW_UNSUPPORTED = %w[development test].include?(
      ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development",
    )
    private_constant :ALLOW_UNSUPPORTED

    MEMORY_BYTES_LIMIT = 4 * 1024 * 1024 * 1024
    private_constant :MEMORY_BYTES_LIMIT

    FILE_SIZE_BYTES_LIMIT = 10 * 1024 * 1024 * 1024
    private_constant :FILE_SIZE_BYTES_LIMIT

    OPEN_FILES_LIMIT = 1024
    private_constant :OPEN_FILES_LIMIT

    def initialize(
      exchange_dir:,
      scratch_dir:,
      input: $stdin,
      output: $stdout,
      allow_unsupported: ALLOW_UNSUPPORTED
    )
      @exchange_dir = File.expand_path(exchange_dir)
      @scratch_dir = File.expand_path(scratch_dir)
      @input = input
      @output = output
      @allow_unsupported = allow_unsupported
    end

    def run
      @output.sync = true
      Process.setpriority(Process::PRIO_PROCESS, 0, 10)
      ENV["TMPDIR"] = @scratch_dir
      ENV["HOME"] = @scratch_dir
      ENV["XDG_CACHE_HOME"] = @scratch_dir
      Vips.cache_set_max(0)
      warm_up
      restrict!

      while (line = @input.gets)
        @output.puts(JSON.generate(respond(line)))
      end
    end

    private

    def respond(line)
      { status: "ok", value: execute(JSON.parse(line)) }
    rescue StandardError => error
      { status: "error", message: error.message }
    end

    def execute(request)
      arguments = request.fetch("arguments", {})

      case request.fetch("operation")
      when "version"
        Operations.version
      when "generate_letter_avatar"
        Operations.generate_letter_avatar(
          markup: arguments.fetch("markup"),
          font: arguments.fetch("font"),
          font_path: font_path(arguments.fetch("font_path")),
          background_color: arguments.fetch("background_color"),
          output_path: exchange_path(arguments.fetch("output")),
        )
      when "resize_letter_avatar"
        Operations.resize_letter_avatar(
          input_path: exchange_path(arguments.fetch("input")),
          output_path: exchange_path(arguments.fetch("output")),
          size: arguments.fetch("size"),
        )
      when "dominant_color"
        Operations.dominant_color(input_path: exchange_path(arguments.fetch("input")))
      when "svg_to_png"
        Operations.svg_to_png(
          input_path: exchange_path(arguments.fetch("input")),
          output_path: exchange_path(arguments.fetch("output")),
        )
      else
        raise ArgumentError, "unknown operation"
      end
    end

    def exchange_path(name)
      if !name.is_a?(String) || name.empty? || name != File.basename(name) || name.start_with?(".")
        raise ArgumentError, "image names must be plain file names"
      end

      File.join(@exchange_dir, name)
    end

    def font_path(path)
      if !FONT_PATHS.include?(path)
        raise ArgumentError, "font_path must reference a supported font file"
      end
      path
    end

    # Pay libvips' lazy per-operation initialization once, with trusted data.
    def warm_up
      png = File.join(@scratch_dir, "warmup.png")
      Vips::Image.black(8, 8).pngsave(png, compression: 6)
      Vips::Image.thumbnail(png, 4, height: 4, size: :both).sharpen(sigma: 0.5, m1: 0.7).avg
      Vips::Image
        .text("A", dpi: 72, rgba: true)
        .gravity(:centre, 16, 16, extend: :background, background: [0, 0, 0, 255])
        .flatten(background: [0, 0, 0])
        .avg

      svg = File.join(@scratch_dir, "warmup.svg")
      File.write(svg, %(<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>))
      Vips::Image.svgload(svg).flatten.avg
    end

    def restrict!
      if !Landlock.supported?
        raise Landlock::UnsupportedError, "Linux Landlock is unavailable" if !@allow_unsupported
        return
      end

      Process.setrlimit(:AS, MEMORY_BYTES_LIMIT)
      Process.setrlimit(:FSIZE, FILE_SIZE_BYTES_LIMIT)
      Process.setrlimit(:NOFILE, OPEN_FILES_LIMIT)
      Landlock.restrict!(read: read_paths, write: [@exchange_dir, @scratch_dir], execute: [])
      Landlock.seccomp_deny_network!
    end

    def read_paths
      [
        *DEFAULT_READ_PATHS,
        DYNAMIC_LINKER_CACHE_PATH,
        *FONTCONFIG_READ_PATHS,
        *FONT_PATHS,
        *$LOAD_PATH,
        @exchange_dir,
        @scratch_dir,
      ].filter { |path| File.exist?(path) }.uniq
    end
  end
end
