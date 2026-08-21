# frozen_string_literal: true

require "erb"
require "rbconfig"
require "tmpdir"

module DiscourseVips
  VERSION = 1
  DEFAULT_TIMEOUT_SECONDS = 5
  FONT_FAMILIES = { "Helvetica.ttc" => "Helvetica", "NotoSans-Regular.woff2" => "Noto Sans" }.freeze
  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
  DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  RLIMITS = {
    cpu_seconds: 5,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze
  private_constant :DEFAULT_TIMEOUT_SECONDS,
                   :FONT_FAMILIES,
                   :FONTCONFIG_READ_PATHS,
                   :DYNAMIC_LINKER_CACHE_PATH,
                   :RLIMITS

  class Error < RuntimeError
  end

  class << self
    def version
      "#{VERSION}-#{run(command: "version").strip}"
    end

    def generate_letter_avatar(letter:, background_color:, font_path:, output_path:)
      font_family = FONT_FAMILIES[File.basename(font_path.to_s)]
      if !File.file?(font_path.to_s) || !font_family
        raise ArgumentError, "font_path must reference a supported font file"
      end

      red, green, blue = validate_background_color(background_color)
      options = {
        output: output_path,
        size: 360,
        red:,
        green:,
        blue:,
        markup:
          %(<span foreground="#ffffff" alpha="80%">#{ERB::Util.html_escape(letter.to_s)}</span>),
        font: "#{font_family} 280",
        fontfile: font_path,
      }
      run(
        command: "letter-avatar",
        options:,
        read: [font_path, *FONTCONFIG_READ_PATHS],
        write: [File.dirname(output_path)],
      )
      nil
    end

    def resize_letter_avatar(input_path:, output_path:, size:, profile_path:)
      run(
        command: "resize-letter-avatar",
        options: {
          input: input_path,
          output: output_path,
          size:,
          profile: profile_path,
        },
        read: [input_path, profile_path],
        write: [File.dirname(output_path)],
      )
      nil
    end

    def dominant_color(input_path:)
      run(command: "dominant-color", options: { input: input_path }, read: [input_path]).strip
    end

    def generate_topic_og_image(svg_path:, output_path:)
      run(
        command: "topic-og",
        options: {
          input: svg_path,
          output: output_path,
        },
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

    def run(command:, options: {}, read: [], write: [])
      ensure_sandbox_available!

      Dir.mktmpdir("discourse-vips-helper-") do |scratch|
        argv = ["nice", "-n", "10", executable, command]
        options.each do |key, value|
          next if value.nil?
          argv << "--#{key.to_s.tr("_", "-")}" << value.to_s
        end

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

    def ensure_sandbox_available!
      if !Rails.env.local? && !Discourse::SafeExec.landlock_supported?
        raise Error, "Cannot run libvips because Landlock sandboxing is unavailable"
      end
    end

    def executable
      return @executable if @executable

      path =
        Rails
          .root
          .join("vendor", "discourse-vips", RbConfig::CONFIG.fetch("arch"), "discourse_vips_helper")
          .to_s
      if !File.executable?(path)
        raise Error, "discourse-vips is not compiled; run bin/rake discourse_vips:compile"
      end

      @executable = path
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
