# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Classifies an `@name` mention into the `mention_type` stored on
      # `post_mentions`: `"here"`, `"all"`, `"group"` or `"user"`.
      #
      #   * `@here` is recognized by the source's `here_mention` site setting — its
      #     name is configurable, so we don't hard-code `"here"`.
      #   * `@all` is recognized by the literal name `all`.
      #   * group mentions are recognized from the source's group names.
      #   * everything else is a user mention.
      #
      # Names are normalized like Discourse does it (Unicode NFC, then downcase), so
      # a mention and a group/user name compare equal however the source encoded
      # them. The importer remaps the recorded name to a destination user or group.
      class MentionResolver
        # @param here_mention [String, nil] the source's `here_mention` setting value.
        # @param group_names [Enumerable<String>] the source's group names.
        def initialize(here_mention: "here", group_names: [])
          @here_mention = normalize(here_mention) if here_mention
          @group_names = group_names.map { |name| normalize(name) }.to_set
        end

        # @param name [String] the mention name (without the leading `@`).
        # @return [String] one of the {Migrations::MentionType} values.
        def call(name)
          normalized = normalize(name)

          return MentionType::HERE if @here_mention && normalized == @here_mention
          return MentionType::ALL if normalized == MentionType::ALL
          return MentionType::GROUP if @group_names.include?(normalized)

          MentionType::USER
        end

        private

        # Matches `User.normalize_username` in core.
        def normalize(name)
          name.unicode_normalize.downcase
        end
      end
    end
  end
end
