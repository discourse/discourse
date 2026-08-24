# frozen_string_literal: true

module DiscourseVips
  VERSION = 1
  DEFAULT_TIMEOUT_SECONDS = 5
  DEFAULT_READ_PATHS = %w[/bin /lib /lib64 /usr].freeze
  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
  DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  ALLOW_UNSUPPORTED = %w[development test].include?(
    ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development",
  )
  RLIMITS = {
    cpu_seconds: 5,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze

  def self.socket_path
    ENV["DISCOURSE_VIPS_SOCKET_PATH"] || File.expand_path("../../tmp/discourse-vips.sock", __dir__)
  end

  def self.remove_owned_pid_file(pid_file)
    File.delete(pid_file) if pid_file && File.read(pid_file).to_i == Process.pid
  rescue Errno::ENOENT
  end

  private_constant :DEFAULT_TIMEOUT_SECONDS,
                   :DEFAULT_READ_PATHS,
                   :FONTCONFIG_READ_PATHS,
                   :DYNAMIC_LINKER_CACHE_PATH,
                   :ALLOW_UNSUPPORTED,
                   :RLIMITS
end
