# frozen_string_literal: true

require "tempfile"

module BulkImport
  module DiscourseMerge
    module Artifacts
      def self.write(path, contents, replace: true)
        path = Pathname.new(path)
        Tempfile.create(%w[.merge- .tmp], path.dirname) do |file|
          file.binmode
          file.chmod(0o600)
          file.write(contents)
          file.flush
          file.fsync
          if replace
            File.rename(file.path, path)
          else
            File.link(file.path, path)
          end
        end
      end

      def self.csv_encode(value)
        text = value.to_s
        text.match?(/\A[=+\-@'\t\r\n]/) ? "'#{text}" : text
      end

      def self.csv_decode(value)
        value.to_s.sub(/\A'(?=[=+\-@'\t\r\n])/, "")
      end

      def self.upload_path(root, relative, existing: true)
        root = Pathname.new(root).realpath
        relative = Pathname.new(relative)
        if relative.absolute? || relative.each_filename.any? { |part| %w[. ..].include?(part) }
          raise Error, "Unsafe upload path"
        end
        path = root.join(relative)
        ancestor = path
        while ancestor != root
          raise Error, "Upload path contains a symlink" if ancestor.symlink?
          ancestor = ancestor.parent
        end
        if existing && (!path.file? || !path.realpath.to_s.start_with?(root.to_s + "/"))
          raise Error, "Upload escapes its root or is missing"
        end
        path
      end
    end
  end
end
