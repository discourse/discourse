# frozen_string_literal: true
require_relative "rspec_file_metadata"

module RspecFileAccess
  FILE_PATH = File.instance_method(:path)
  EXPAND_PATH = File.method(:expand_path)
  REALPATH = File.method(:realpath)
  COERCE_PATH = File.method(:path)
  COERCE_IO = IO.method(:try_convert)
  MATCH_GLOB = File.method(:fnmatch?)
  private_constant :FILE_PATH, :EXPAND_PATH, :REALPATH, :COERCE_PATH, :COERCE_IO, :MATCH_GLOB

  class PathArgument
    def initialize(original, shared: false)
      @shared = shared
      @original = original
      @inputs = []
    end

    def to_io
      io = COERCE_IO.call(@original)
      @inputs << io if io.is_a?(File)
      io
    end

    def to_path
      path = COERCE_PATH.call(@original)
      @inputs << String.new(path)
      RspecFileAccess.record(path) if @shared
      path
    end

    def paths
      @inputs.filter_map { |input| input.is_a?(File) ? FILE_PATH.bind_call(input) : input }
    end
  end
  private_constant :PathArgument

  def self.metadata_observer(methods:, skip_arguments: 0, private_methods: false)
    Module.new do
      private if private_methods
      methods.each do |name|
        define_method(name) do |*arguments, **options, &block|
          completed = false
          inputs = skip_arguments.zero? ? arguments : arguments.drop(skip_arguments)
          inputs.each_with_index do |path, index|
            next if index == 1 && %i[realpath realdirpath].include?(name) && nil.equal?(path)
            if !(String === path) && !(IO === path)
              inputs[index] = PathArgument.new(path)
              arguments[skip_arguments + index] = inputs[index]
            end
          end
          value = super(*arguments, **options, &block)
          completed = true
          value
        ensure
          RspecFileAccess.record_metadata(
            method: name,
            arguments: inputs,
            value: completed ? value : :failed,
          )
        end
      end
    end
  end
  private_class_method :metadata_observer

  FileMetadataReads = metadata_observer(methods: RspecFileMetadata.method_names)
  TestMetadataReads = metadata_observer(methods: FileTest.singleton_methods(false))
  PrivateTestMetadataReads =
    metadata_observer(methods: FileTest.singleton_methods(false), private_methods: true)
  StatMetadataReads = metadata_observer(methods: [:new])
  KernelMetadataReads = metadata_observer(methods: [:test], skip_arguments: 1)
  PrivateKernelMetadataReads =
    metadata_observer(methods: [:test], skip_arguments: 1, private_methods: true)
  private_constant :FileMetadataReads,
                   :TestMetadataReads,
                   :PrivateTestMetadataReads,
                   :StatMetadataReads,
                   :KernelMetadataReads,
                   :PrivateKernelMetadataReads

  module ClassReads
    %i[read binread readlines foreach open new sysopen].each do |name|
      define_method(name) do |*arguments, **options, &block|
        if !%i[open new].include?(name) || self == IO || self <= File
          path = arguments.first
          if !%i[open new].include?(name) && !arguments.empty? && !(String === path)
            arguments[0] = PathArgument.new(path, shared: true)
          else
            RspecFileAccess.record(path)
          end
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

  def self.enable(root: Dir.pwd)
    @root = "#{root}/"
    @shared_files = Set.new
    @metadata = Hash.new { |hash, path| hash[path] = [] }
    @cache = {}
    @failure = nil
    @globs = []
    IO.singleton_class.prepend(ClassReads)
    File.prepend(InstanceReads)
    File.singleton_class.prepend(FileMetadataReads)
    FileTest.singleton_class.prepend(TestMetadataReads)
    FileTest.prepend(PrivateTestMetadataReads)
    File::Stat.singleton_class.prepend(StatMetadataReads)
    Kernel.singleton_class.prepend(KernelMetadataReads)
    Kernel.prepend(PrivateKernelMetadataReads)
  end

  def self.configure_shared_globs(globs)
    @globs = globs
    @cache.clear
    @shared_files.delete_if { |path| ignored?(path) }
    @metadata.delete_if { |path, _descriptions| ignored?(path) }
  end

  def self.shared_files
    @shared_files.to_a
  end

  def self.failure
    @failure
  end

  def self.metadata
    @metadata.to_h
  end

  def self.record_metadata(method:, arguments:, value:)
    if %i[realpath realdirpath].include?(method) && arguments.length == 2
      path_candidates, base_candidates =
        arguments.map do |argument|
          candidates = argument.is_a?(PathArgument) ? argument.paths : [argument]
          candidates.empty? ? [nil] : candidates
        end
      arguments =
        path_candidates.product(base_candidates).map { |path, base| EXPAND_PATH.call(path, base) }
    end
    description = RspecFileMetadata.describe(method: method, value: value, root: @root.chomp("/"))
    if arguments.length == 1 && description
      paths(arguments.first).each { |path| @metadata[path] |= [description] }
    else
      arguments.each { |path| record(path) }
    end
    nil
  rescue ArgumentError, TypeError
    nil
  rescue StandardError => error
    @failure ||= "#{error.class}: #{error.message}".scrub.slice(0, 500)
    nil
  end

  def self.record_file(file)
    record(FILE_PATH.bind_call(file))
  rescue IOError
    nil
  end

  def self.record(path)
    @shared_files.merge(paths(path))
    nil
  rescue ArgumentError, TypeError
    nil
  rescue StandardError => error
    @failure ||= "#{error.class}: #{error.message}".scrub.slice(0, 500)
    nil
  end

  def self.paths(path)
    return path.paths.flat_map { |input| paths(input) }.uniq if path.is_a?(PathArgument)
    path = path.to_path if path.instance_of?(Pathname)
    return [] unless path.is_a?(String)
    absolute = EXPAND_PATH.call(path)
    return [] unless absolute.start_with?(@root)
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
      return []
    end
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
  end
  private_class_method :paths

  def self.ignored?(path)
    @globs.any? { |pattern| MATCH_GLOB.call(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
  end
  private_class_method :ignored?
end
