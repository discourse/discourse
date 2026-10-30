# frozen_string_literal: true

module ::Blog
  module SyntaxHighlighter
    def self.source
      @source ||= File.read(File.expand_path("../../vendor/highlightjs/core.min.js", __dir__))
    end

    def self.version
      @version ||= Digest::SHA256.hexdigest(source)
    end

    def self.path
      "/blog-highlight/#{version}.js"
    end
  end
end
