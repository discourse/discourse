# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class GetDraft
      REQUIRED_SCOPES = [Scopes::DRAFTS_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          optional: %w[sequence data],
          draft_key: OutputSchema::STRING,
          sequence: OutputSchema::INTEGER,
          found: OutputSchema::BOOLEAN,
          data: OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")
        absent = ToolHelpers.text_and_structured(draft_key:, found: false)
        # While agent access to personal messages is off, a personal-message
        # draft reads exactly like a missing one.
        private_messages_denied = ToolHelpers.private_messages_denied?(request_context)
        return absent if private_messages_denied && ToolHelpers.private_message_draft?(draft_key)
        return absent if ToolHelpers.restricted_draft?(draft_key, request_context)
        ToolHelpers.ensure_private_message_draft_scope!(draft_key, request_context, access: :read)

        sequence =
          if arguments.key?("sequence")
            arguments.fetch("sequence")
          else
            DraftSequence.current(user, draft_key)
          end
        draft = Draft.get(user, draft_key, sequence)

        return absent if draft.blank?

        parsed = JSON.parse(draft)
        parsed = {} if !parsed.is_a?(Hash)
        if private_messages_denied &&
             ToolHelpers.private_message_draft?(
               draft_key,
               action: parsed["action"],
               archetype: parsed["archetypeId"],
             )
          return absent
        end
        return absent if ToolHelpers.restricted_draft?(draft_key, request_context, data: parsed)
        ToolHelpers.ensure_private_message_draft_scope!(
          draft_key,
          request_context,
          access: :read,
          action: parsed["action"],
          archetype: parsed["archetypeId"],
        )

        ToolHelpers.text_and_structured(
          draft_key:,
          sequence:,
          found: true,
          data: {
            title: parsed["title"],
            reply: parsed["reply"],
            category_id: parsed["categoryId"],
            tags:
              (
                if parsed["tags"].is_a?(Array)
                  parsed["tags"].select { |tag| request_context.content_policy.allows_tag?(tag) }
                else
                  []
                end
              ),
            action: parsed["action"],
          },
        )
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      rescue JSON::ParserError
        ToolHelpers.text_and_structured(
          draft_key:,
          sequence:,
          found: true,
          data: {
            title: nil,
            reply: nil,
            category_id: nil,
            tags: [],
            action: nil,
          },
        )
      end
    end

    class SaveDraft
      REQUIRED_SCOPES = [Scopes::DRAFTS_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          draft_key: OutputSchema::STRING,
          sequence: OutputSchema::INTEGER,
          saved: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")
        action = arguments["action"] || default_action(draft_key)
        not_found = ToolHelpers.ensure_draft_topic!(draft_key, request_context)
        ToolHelpers.ensure_private_message_draft_scope!(
          draft_key,
          request_context,
          access: :write,
          action:,
          not_found:,
        )
        ToolHelpers.ensure_private_message_stored_draft_scope!(
          Draft.find_by(user_id: user.id, draft_key:),
          request_context,
          access: :write,
          not_found:,
        )

        if !Draft.exists?(user_id: user.id, draft_key:) &&
             Draft.where(user_id: user.id).count >= SiteSetting.max_drafts_per_user
          raise DiscourseMcp::ToolError, I18n.t("draft.too_many_drafts.title")
        end

        if request_context.content_policy.active? && arguments["tags"].present?
          ensure_allowed_tags!(arguments["tags"], request_context)
        end

        data = { reply: arguments.fetch("reply") }
        data[:action] = action if action.present?
        data[:title] = arguments["title"] if arguments.key?("title")
        data[:categoryId] = arguments["category_id"] if arguments.key?("category_id")
        data[:tags] = arguments["tags"] if arguments["tags"].present?

        if (match = draft_key.match(/\Atopic_(\d+)\z/))
          data[:topic_id] = match[1].to_i
        end

        serialized_data = data.to_json
        if serialized_data.length > SiteSetting.max_draft_length
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_too_long")
        end

        # The backup copy is a personal message written as a side effect, so it
        # isn't made while a rule is active.
        sequence =
          Draft.set(
            user,
            draft_key,
            arguments.fetch("sequence", 0),
            serialized_data,
            backup: !request_context.content_policy.active?,
          )
        ToolHelpers.text_and_structured(draft_key:, sequence:, saved: true)
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      end

      # Draft tags are only names until a later save publishes them, so they
      # must resolve to tags that exist and aren't denied. Both refusals look
      # the same.
      def self.ensure_allowed_tags!(tag_names, request_context)
        tag_ids = ToolHelpers.prospective_tag_ids!(request_context, tag_names:, category_id: nil)
        if tag_ids.intersect?(request_context.content_policy.restricted_tag_ids)
          ToolHelpers.raise_prospective_refusal!
        end
      end
      private_class_method :ensure_allowed_tags!

      def self.default_action(draft_key)
        return "createTopic" if draft_key == Draft::NEW_TOPIC
        return "privateMessage" if draft_key == Draft::NEW_PRIVATE_MESSAGE
        "reply" if draft_key.match?(/\Atopic_\d+\z/)
      end
      private_class_method :default_action
    end

    class DeleteDraft
      REQUIRED_SCOPES = [Scopes::DRAFTS_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(draft_key: OutputSchema::STRING, deleted: OutputSchema::BOOLEAN)

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")
        not_found = ToolHelpers.ensure_draft_topic!(draft_key, request_context)
        ToolHelpers.ensure_private_message_draft_scope!(
          draft_key,
          request_context,
          access: :write,
          not_found:,
        )
        ToolHelpers.ensure_private_message_stored_draft_scope!(
          Draft.find_by(user_id: user.id, draft_key:),
          request_context,
          access: :write,
          not_found:,
        )
        Draft.clear(user, draft_key, arguments.fetch("sequence"))
        ToolHelpers.text_and_structured(draft_key:, deleted: true)
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      end
    end
  end
end
