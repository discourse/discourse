# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred quote reference: the opening `[quote="…"]` tag alone. That
        # tag is all the detector consumes — the body and `[/quote]` stay in the
        # raw and are scanned like any other text — and all that carries the
        # references needing remapping, so this is a reference, not a quote
        # block with children.
        #
        # `name` is the quoted user's display name, kept only when the header
        # gives one that differs from the username (else `nil`); it's the fallback
        # text when the user can't be mapped at import.
        #
        # `post_number` and `topic_id` are the source coordinates of the quoted post
        # (both `Integer` or `nil`); the importer turns them into a source post
        # `original_id`. They are the source's own numbering, not Discourse ids.
        QuoteReference = Data.define(:username, :name, :post_number, :topic_id)
      end
    end
  end
end
