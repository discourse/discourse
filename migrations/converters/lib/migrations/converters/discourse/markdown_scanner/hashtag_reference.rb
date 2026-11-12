# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred hashtag (`#slug`, `#parent:child`, or a forced `#name::tag`
        # / `#name::category`). `name` is the text between the `#` and any `::`
        # suffix, so it keeps the `parent:child` separator but drops the suffix.
        # `forced_type` is `:category`, `:tag`, or nil when the source didn't
        # pin the type; the importer classifies the untyped ones. The category
        # or tag is named, not identified — its slug or name can change at
        # import.
        HashtagReference = Data.define(:name, :forced_type)
      end
    end
  end
end
