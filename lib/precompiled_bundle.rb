# frozen_string_literal: true

# A JS bundle built by an external command and cached on disk, keyed by a digest
# of its inputs. Precompiled during `assets:precompile`; held by composition.
class PrecompiledBundle
  def initialize(dir:, filename_prefix:, dependency_globs:, &build)
    @dir = dir
    @filename_prefix = filename_prefix
    @dependency_globs = dependency_globs
    @build = build
  end

  def path
    Rails.root.join(@dir, "#{@filename_prefix}-#{digest}.js")
  end

  def precompiled?
    File.exist?(path)
  end

  def load_or_build
    cache_path = path
    return File.read(cache_path) if File.exist?(cache_path)

    with_lock do
      return File.read(cache_path) if File.exist?(cache_path)
      source = @build.call
      FileUtils.mkdir_p(File.dirname(cache_path))
      File.write(cache_path, source)
      cleanup_old(cache_path)
      source
    end
  end

  private

  def digest
    digest = Digest::MD5.new
    @dependency_globs.each do |pattern|
      files = Dir.glob(pattern, base: Rails.root).sort
      raise "No files matched #{pattern}" if files.empty?

      files.each do |file|
        digest.update(file)
        digest.update(File.read(Rails.root.join(file)))
      end
    end
    digest.hexdigest.to_i(16).to_s(36)
  end

  def with_lock(&block)
    lock_path = Rails.root.join(@dir, "build.lock")
    FileUtils.mkdir_p(File.dirname(lock_path))
    File.open(lock_path, File::CREAT | File::RDWR) do |lock_file|
      lock_file.flock(File::LOCK_EX)
      yield
    end
  end

  def cleanup_old(keep)
    Dir
      .glob(Rails.root.join(@dir, "#{@filename_prefix}-*.js"))
      .each { |file| File.delete(file) unless file == keep.to_s }
  end
end
