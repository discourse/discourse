# frozen_string_literal: true

class DiskSpace
  class << self
    def uploads_used_bytes
      Upload.sum(:filesize).to_i + OptimizedImage.sum(:filesize).to_i
    end

    def uploads_free_bytes
      return nil if Discourse.store.external?

      free(uploads_path)
    end

    def free(path)
      output = Discourse::Utils.execute_command("df", "-Pk", path)
      size_line = output.split("\n")[1]
      size_line.split(/\s+/)[3].to_i * 1024
    end

    def percent_free(path)
      output = Discourse::Utils.execute_command("df", "-P", path)
      size_line = output.split("\n")[1]
      size_line.split(/\s+/)[4].to_i
    end

    def used(path)
      Discourse::Utils.execute_command("du", "-s", path).to_i * 1024
    end

    def uploads_path
      "#{Rails.root.join("public/#{Discourse.store.upload_path}")}"
    end
  end

  private_class_method :uploads_path
end
