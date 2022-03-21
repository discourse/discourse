# frozen_string_literal: true

require "fileutils"

# See: https://github.com/docker/for-linux/issues/1015

module FreedomPatches
  module CopyFile
    def copy_file(dest)
      File.open(path()) do |s|
        File.open(dest, "wb", s.stat.mode) do |f|
          IO.copy_stream(s, f)
          f.chmod(f.lstat.mode)
        end
      end
    end

    FileUtils::Entry_.prepend(self)
  end
end
