# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred custom emoji (`:name:`). `name` is the shortcode without the
        # surrounding colons. Only the source's own custom emoji are recorded; a
        # standard emoji shortcode is left as plain text. The name is what a conflict
        # renames at import, so the importer rewrites it there.
        EmojiReference = Data.define(:name)
      end
    end
  end
end
