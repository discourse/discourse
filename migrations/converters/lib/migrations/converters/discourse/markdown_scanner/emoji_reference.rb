# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred custom emoji (`:name:`). `name` is the shortcode without
        # the surrounding colons, in the author's own spelling; an import-time
        # conflict may rename it, so the importer rewrites it there.
        EmojiReference = Data.define(:name)
      end
    end
  end
end
