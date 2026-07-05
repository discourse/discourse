# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred quote attribution. Markbridge has no quote AST node of this
        # shape (its `AST::Quote` is a full block element), and only the opening
        # `[quote="…"]` carries the post/topic/user references that need remapping.
        QuoteAttribution = Data.define(:username, :post)
      end
    end
  end
end
