# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred quote attribution. Markbridge has no quote AST node of this
        # shape (its `AST::Quote` is a full block element), and only the opening
        # `[quote="…"]` carries the post/topic/user references that need remapping.
        #
        # `name` is the quoted user's display name, kept only when the attribution
        # gives one that differs from the username (else `nil`); it's the fallback
        # text when the user can't be mapped at import.
        #
        # `post_number` and `topic_id` are the source coordinates of the quoted post
        # (both `Integer` or `nil`); the importer turns them into a source post
        # `original_id`. They are the source's own numbering, not Discourse ids.
        QuoteAttribution = Data.define(:username, :name, :post_number, :topic_id)
      end
    end
  end
end
