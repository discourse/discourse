# frozen_string_literal: true

module Migrations
  # The mention types, shared by the converter that records a mention
  # (`Converters::EmbedBuffer`) and the importer that resolves it
  # (`Importer::PlaceholderResolver`). One list means the two sides can't disagree
  # on a spelling: a typo like "Group" would otherwise be treated as a username.
  module MentionType
    HERE = "here"
    ALL = "all"
    GROUP = "group"
    USER = "user"

    # All valid types. `nil` is also allowed when recording a mention; it means a
    # plain `@username` and is treated as USER.
    TYPES = [HERE, ALL, GROUP, USER].freeze
  end
end
