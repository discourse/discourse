# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Single-pass scanner for Discourse Markdown that extracts specific constructs
      # (uploads, internal links, quote references, mentions, hashtags, custom
      # emoji) while leaving everything else untouched — including anything inside
      # fenced, indented or inline code.
      #
      # {Scanner} walks the input; on a successful match it asks the supplied block
      # for the replacement text (a placeholder token) and skips past the matched
      # span. The pieces live in `markdown_scanner/`: {Scanner}, {CodeBlockTracker}
      # and the {Detectors}.
      module MarkdownScanner
      end
    end
  end
end
