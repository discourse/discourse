# frozen_string_literal: true

require "json"
require "tmpdir"

require_relative "../freedom_patches/landlock_capture_fork"
require_relative "operations"

module DiscourseVips
  class Worker
    DEFAULT_TIMEOUT_SECONDS = 5
    private_constant :DEFAULT_TIMEOUT_SECONDS

    SVG_TO_PNG_TIMEOUT_SECONDS = 20
    private_constant :SVG_TO_PNG_TIMEOUT_SECONDS

    DEFAULT_READ_PATHS = %w[/bin /lib /lib64 /usr].freeze
    private_constant :DEFAULT_READ_PATHS

    FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
    private_constant :FONTCONFIG_READ_PATHS

    DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
    private_constant :DYNAMIC_LINKER_CACHE_PATH

    ALLOW_UNSUPPORTED = %w[development test].include?(
      ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development",
    )
    private_constant :ALLOW_UNSUPPORTED

    RLIMITS = {
      cpu_seconds: 5,
      memory_bytes: 4 * 1024 * 1024 * 1024,
      file_size_bytes: 10 * 1024 * 1024 * 1024,
      open_files: 1024,
    }.freeze
    private_constant :RLIMITS

    MAX_OUTPUT_BYTES = 64 * 1024
    private_constant :MAX_OUTPUT_BYTES

    OPERATIONS = {
      "version" => :version,
      "generate_letter_avatar" => :generate_letter_avatar,
      "resize_letter_avatar" => :resize_letter_avatar,
      "dominant_color" => :dominant_color,
      "svg_to_png" => :svg_to_png,
    }.freeze
    private_constant :OPERATIONS

    def initialize(input: $stdin, output: $stdout, allow_unsupported: ALLOW_UNSUPPORTED)
      @input = input
      @output = output
      @allow_unsupported = allow_unsupported
    end

    def run
      @output.sync = true

      while (line = @input.gets)
        @output.puts(JSON.generate(respond(line)))
      end
    end

    private

    def respond(line)
      execute(JSON.parse(line))
    rescue StandardError => error
      { status: "error", message: error.message }
    end

    def execute(request)
      operation = request.fetch("operation")
      arguments = request.fetch("arguments", {}).transform_keys(&:to_sym)
      method_name = OPERATIONS.fetch(operation)

      Dir.mktmpdir("discourse-vips-") do |scratch|
        result =
          Landlock.capture_fork(
            read: read_paths(operation, arguments),
            write: [scratch, *write_paths(operation, arguments)],
            execute: [],
            timeout:
              operation == "svg_to_png" ? SVG_TO_PNG_TIMEOUT_SECONDS : DEFAULT_TIMEOUT_SECONDS,
            env: environment(scratch),
            unsetenv_others: true,
            rlimits: rlimits,
            seccomp_deny_network: true,
            max_output_bytes: MAX_OUTPUT_BYTES,
            allow_unsupported: @allow_unsupported,
          ) do
            Process.setpriority(Process::PRIO_PROCESS, 0, 10)
            value = Operations.public_send(method_name, **arguments)
            STDOUT.write(JSON.generate(value:))
          end

        return { status: "timeout" } if result.timed_out?
        return { status: "error", message: result.stderr.strip } if !result.status&.success?

        { status: "ok", **JSON.parse(result.stdout) }
      end
    end

    def rlimits
      Landlock.supported? ? RLIMITS : RLIMITS.except(:memory_bytes)
    end

    def read_paths(operation, arguments)
      operation_paths =
        case operation
        when "generate_letter_avatar"
          [arguments.fetch(:font_path), *FONTCONFIG_READ_PATHS]
        when "resize_letter_avatar"
          [arguments.fetch(:input_path)]
        when "dominant_color"
          [arguments.fetch(:input_path)]
        when "svg_to_png"
          [File.dirname(arguments.fetch(:input_path)), *FONTCONFIG_READ_PATHS]
        else
          []
        end

      [*DEFAULT_READ_PATHS, DYNAMIC_LINKER_CACHE_PATH, *operation_paths].filter do |path|
          path.to_s != "" && File.exist?(path)
        end
        .uniq
    end

    def write_paths(operation, arguments)
      case operation
      when "generate_letter_avatar", "resize_letter_avatar", "svg_to_png"
        [File.dirname(arguments.fetch(:output_path))]
      else
        []
      end
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
  end
end
