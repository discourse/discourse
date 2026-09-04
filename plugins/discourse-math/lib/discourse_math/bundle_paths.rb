# frozen_string_literal: true

require "fileutils"

module DiscourseMath
  module BundlePaths
    PLUGIN_NAME = "discourse-math"
    PUBLIC_DIR = File.expand_path("../../public", __dir__)

    class << self
      def bundle_version
        DiscourseMathBundle::VERSION
      end

      def public_version_dir
        File.join(PUBLIC_DIR, bundle_version)
      end

      def public_url_base
        "/plugins/#{PLUGIN_NAME}/#{bundle_version}"
      end

      def ensure_public_symlinks
        FileUtils.mkdir_p(public_version_dir)
        ensure_symlink(File.join(public_version_dir, "mathjax"), DiscourseMathBundle.mathjax_path)
        ensure_symlink(File.join(public_version_dir, "katex"), DiscourseMathBundle.katex_path)
      end

      def ensure_symlink(link_path, target_path)
        return if File.symlink?(link_path) && File.readlink(link_path) == target_path

        Discourse::Utils.atomic_ln_s(target_path, link_path)
      end
    end
  end
end
