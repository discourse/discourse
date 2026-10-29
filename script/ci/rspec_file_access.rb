# frozen_string_literal: true

require "pathname"

module RspecFileAccess
  FILE_PATH = File.instance_method(:path)
  EXPAND_PATH = File.method(:expand_path)
  REALPATH = File.method(:realpath)
  MATCH_GLOB = File.method(:fnmatch?)
  private_constant :FILE_PATH, :EXPAND_PATH, :REALPATH, :MATCH_GLOB

  module ClassReads
    %i[read binread readlines foreach open new sysopen].each do |name|
      define_method(name) do |*arguments, **options, &block|
        if !%i[open new].include?(name) || self == IO || self <= File
          RspecFileAccess.record(arguments.first)
        end
        super(*arguments, **options, &block)
      end
    end
  end

  module InstanceReads
    %i[
      read
      readpartial
      read_nonblock
      readlines
      gets
      getc
      each_line
      each_byte
      each_char
      sysread
      pread
    ].each do |name|
      define_method(name) do |*arguments, **options, &block|
        RspecFileAccess.record_file(self)
        super(*arguments, **options, &block)
      end
    end
  end

  def self.enable
    @root = "#{Dir.pwd}/"
    @shared_files = Set.new
    @cache = {}
    @failure = nil
    @globs = []
    IO.singleton_class.prepend(ClassReads)
    File.prepend(InstanceReads)
  end

  def self.configure_shared_globs(globs)
    @globs = globs
    @cache.clear
    @shared_files.delete_if { |path| ignored?(path) }
  end

  def self.shared_files
    @shared_files.to_a
  end

  def self.failure
    @failure
  end

  def self.record_file(file)
    record(FILE_PATH.bind_call(file))
  rescue IOError
    nil
  end

  def self.record(path)
    path = path.to_path if path.instance_of?(Pathname)
    return unless path.is_a?(String)
    absolute = EXPAND_PATH.call(path)
    return unless absolute.start_with?(@root)
    relative = absolute.delete_prefix(@root)
    if relative.start_with?(
         "tmp/",
         "log/",
         "node_modules/",
         "vendor/bundle/",
         "public/assets/",
         "public/uploads/",
         "spec/fixtures/",
         "db/",
       ) || relative.include?("/node_modules/")
      return
    end
    paths =
      @cache.fetch(relative) do
        resolved =
          begin
            REALPATH.call(absolute).delete_prefix(@root)
          rescue SystemCallError
            relative
          end
        candidates = [relative]
        candidates << resolved unless resolved.start_with?("/")
        @cache[relative] = candidates.uniq.reject { |candidate| ignored?(candidate) }
      end
    @shared_files.merge(paths)
    nil
  rescue ArgumentError, TypeError
    nil
  rescue StandardError => error
    @failure ||= "#{error.class}: #{error.message}".scrub.slice(0, 500)
    nil
  end

  def self.ignored?(path)
    @globs.any? { |pattern| MATCH_GLOB.call(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
  end
  private_class_method :ignored?
end
