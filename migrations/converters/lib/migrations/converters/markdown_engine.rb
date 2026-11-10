# frozen_string_literal: true

module Migrations
  module Converters
    # A self-contained discourse-markdown-it engine for scanning post markdown
    # during a conversion: the same parser, features, and options the target
    # site will use, but without a booted Rails application or a local site
    # database. Parse-only — it never renders, sanitizes, or resolves
    # render-time data.
    #
    # {MarkdownEngine::Bundle} prepares all checkout-derived JavaScript once, in
    # the parent process; {MarkdownEngine::Context} is the per-worker V8 wrapper
    # built from a bundle and a {MarkdownEngine::Config} of source-site inputs.
    module MarkdownEngine
      def self.discourse_root
        Migrations.host_app_root
      end
    end
  end
end
