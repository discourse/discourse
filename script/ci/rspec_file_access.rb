# frozen_string_literal: true
require_relative "rspec_file_metadata"

module RspecFileAccess
  FILE_PATH = File.instance_method(:path)
  EXPAND_PATH = File.method(:expand_path)
  REALPATH = File.method(:realpath)
  MATCH_GLOB = File.method(:fnmatch?)
  private_constant :FILE_PATH, :EXPAND_PATH, :REALPATH, :MATCH_GLOB

  def self.metadata_observer(methods:, skip_arguments: 0, private_methods: false)
    Module.new do
      private if private_methods
      methods.each do |name|
        define_method(name) do |*arguments, **options, &block|
          inputs = skip_arguments.zero? ? arguments : arguments.drop(skip_arguments)
          value = super(*arguments, **options, &block)
        rescue SystemCallError, NotImplementedError => error
          RspecFileAccess.record_metadata(method: name, arguments: inputs, value: error)
          raise
        else
          RspecFileAccess.record_metadata(method: name, arguments: inputs, value: value)
          value
        end
      end
    end
  end
  private_class_method :metadata_observer

  FileMetadataReads = metadata_observer(methods: RspecFileMetadata.method_names)
  TestMetadataReads = metadata_observer(methods: FileTest.singleton_methods(false))
  StatMetadataReads = metadata_observer(methods: [:new])
  KernelMetadataReads = metadata_observer(methods: [:test], skip_arguments: 1)
  PrivateKernelMetadataReads =
    metadata_observer(methods: [:test], skip_arguments: 1, private_methods: true)
  private_constant :FileMetadataReads,
                   :TestMetadataReads,
                   :StatMetadataReads,
                   :KernelMetadataReads,
                   :PrivateKernelMetadataReads

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
      arguments = [EXPAND_PATH.call(*arguments)]
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
