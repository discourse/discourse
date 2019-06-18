# frozen_string_literal: true

module DirectoryHelper

  def tmp_directory(prefix)
    directory_cache[prefix] ||= begin
      f = File.join(Rails.root, 'tmp', Time.now.strftime("#{prefix}%Y%m%d%H%M%S"))
      FileUtils.mkdir_p(f) unless Dir[f].present?
      f
    end
  end

  def remove_tmp_directory(prefix)
    tmp_directory_name = directory_cache[prefix] || ''
    directory_cache.delete(prefix)
    FileUtils.rm_rf(tmp_directory_name) if Dir[tmp_directory_name].present?
  end

  private
  def directory_cache
    @directory_cache ||= {}
  end

end
