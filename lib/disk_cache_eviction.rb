# frozen_string_literal: true

class DiskCacheEviction
  def self.evict(dir:, max_entries:, evict_count:)
    pattern = File.join(dir.to_s, "*")
    files = Dir.glob(pattern)
    return if files.length <= max_entries

    oldest =
      files.min_by(evict_count) do |f|
        File.mtime(f)
      rescue Errno::ENOENT
        Time.new(0)
      end

    FileUtils.rm_f(oldest)
  end
end
