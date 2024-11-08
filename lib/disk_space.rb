# frozen_string_literal: true

class DiskSpace
  def self.uploads_used_bytes
    Upload.sum(:filesize).to_i + OptimizedImage.sum(:filesize).to_i
  end

  def self.uploads_free_bytes
    if Discourse.store.external?
      0
    else
      free(uploads_path)
    end
  end

  def self.free(path)
    output = Discourse::Utils.execute_command("df", "-Pk", path)
    size_line = output.split("\n")[1]
    size_line.split(/\s+/)[3].to_i * 1024
  end

  def self.percent_free(path)
    output = Discourse::Utils.execute_command("df", "-P", path)
    size_line = output.split("\n")[1]
    size_line.split(/\s+/)[4].to_i
  end

  def self.used(path)
    Discourse::Utils.execute_command("du", "-s", path).to_i * 1024
  end

  def self.uploads_path
    "#{Rails.root}/public/#{Discourse.store.upload_path}"
  end
  private_class_method :uploads_path
end
