# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class GetDraft
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
        sequence =
          if arguments.key?("sequence")
            arguments.fetch("sequence")
          else
            DraftSequence.current(user, draft_key)
          end
        draft = Draft.get(user, draft_key, sequence)

        return ToolHelpers.text_and_structured(draft_key:, found: false) if draft.blank?

        parsed = JSON.parse(draft)
        parsed = {} if !parsed.is_a?(Hash)
        ToolHelpers.text_and_structured(
          draft_key:,
          sequence:,
          found: true,
          data: {
            title: parsed["title"],
            reply: parsed["reply"],
            category_id: parsed["categoryId"],
            tags: parsed["tags"].is_a?(Array) ? parsed["tags"] : [],
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
      OUTPUT_SCHEMA =
        OutputSchema.object(
          draft_key: OutputSchema::STRING,
          sequence: OutputSchema::INTEGER,
          saved: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")

        if !Draft.exists?(user_id: user.id, draft_key:) &&
             Draft.where(user_id: user.id).count >= SiteSetting.max_drafts_per_user
          raise DiscourseMcp::ToolError, I18n.t("draft.too_many_drafts.title")
        end

        data = { reply: arguments.fetch("reply") }
        action = arguments["action"] || default_action(draft_key)
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

        sequence = Draft.set(user, draft_key, arguments.fetch("sequence", 0), serialized_data)
        ToolHelpers.text_and_structured(draft_key:, sequence:, saved: true)
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      end

      def self.default_action(draft_key)
        return "createTopic" if draft_key == Draft::NEW_TOPIC
        return "privateMessage" if draft_key == Draft::NEW_PRIVATE_MESSAGE
        "reply" if draft_key.match?(/\Atopic_\d+\z/)
      end
      private_class_method :default_action
    end

    class DeleteDraft
      OUTPUT_SCHEMA =
        OutputSchema.object(draft_key: OutputSchema::STRING, deleted: OutputSchema::BOOLEAN)

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")
        Draft.clear(user, draft_key, arguments.fetch("sequence"))
        ToolHelpers.text_and_structured(draft_key:, deleted: true)
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      end
    end
  end
end
