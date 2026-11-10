# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred quote reference: the opening `[quote="…"]` tag alone. That
        # tag is all the construct consumes and all that carries references
        # needing remapping — the body and `[/quote]` stay in the raw and are
        # scanned like any other text.
        #
        # `name` is the quoted user's display name, kept only when the header
        # gives one that differs from the username; it's the fallback text when
        # the user can't be mapped at import. `post_number` and `topic_id` are
        # the source's own coordinates of the quoted post, not Discourse ids;
        # the importer turns them into a source post `original_id`.
        QuoteReference = Data.define(:username, :name, :post_number, :topic_id)
      end
    end
  end
end
