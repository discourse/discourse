# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module CategorySupport
      BASIC_ATTRIBUTE_NAMES = %w[
        name
        slug
        description
        parent_category_id
        color
        text_color
        emoji
        icon
      ].freeze
      CATEGORY_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          name: OutputSchema::STRING,
          slug: OutputSchema::STRING,
          description: OutputSchema::STRING_OR_NULL,
          parent_category_id: OutputSchema::INTEGER_OR_NULL,
          color: OutputSchema::STRING,
          text_color: OutputSchema::STRING,
          style_type: OutputSchema::STRING,
          emoji: OutputSchema::STRING_OR_NULL,
          icon: OutputSchema::STRING_OR_NULL,
          position: OutputSchema::INTEGER,
          topic_count: OutputSchema::INTEGER_OR_NULL,
          can_delete: OutputSchema::BOOLEAN,
          updated_at: OutputSchema::STRING,
        )

      module_function

      # A category the content policy restricts answers like a missing one.
      def find_category!(category_id, request_context)
        request_context.guardian.ensure_can_create!(Category)
        category = Category.find_by(id: category_id)
        if category.blank? || !request_context.content_policy.allows_category_id?(category.id)
          raise ToolError, I18n.t("mcp.errors.category_not_found")
        end

        category
      end

      # While agents can't see a parent category, the parent named in the
      # arguments answers like a missing category.
      def ensure_parent_allowed!(arguments, request_context)
        parent_id = arguments["parent_category_id"]
        policy = request_context.content_policy
        return if parent_id.blank? || !policy.restricts_forum?
        return if Category.exists?(id: parent_id) && policy.allows_category_id?(parent_id)

        raise ToolError, I18n.t("mcp.errors.category_not_found")
      end

      def category_json(category, request_context)
        policy = request_context.content_policy
        {
          id: category.id,
          name: category.name,
          slug: category.slug,
          description: category.topic&.first_post&.raw || category.description_text,
          parent_category_id: policy.redact_category_id(category.parent_category_id),
          color: category.color,
          text_color: category.text_color,
          style_type: category.style_type,
          emoji: category.emoji,
          icon: category.icon,
          position: category.position,
          # The count would reveal how many restricted topics the category holds.
          topic_count: policy.restricts_forum? ? nil : category.topic_count,
          can_delete: request_context.guardian.can_delete?(category),
          updated_at: category.updated_at.iso8601,
        }
      end

      def basic_attributes(arguments)
        attributes = arguments.slice(*BASIC_ATTRIBUTE_NAMES)

        if arguments["emoji"].present?
          attributes["emoji"] = arguments["emoji"].strip.sub(/\A:+/, "").sub(/:+\z/, "")
          if attributes["emoji"].blank?
            raise ToolError, I18n.t("mcp.errors.category_emoji_required")
          end
          attributes["style_type"] = "emoji"
        elsif arguments["icon"].present?
          attributes["style_type"] = "icon"
        end

        attributes
      end
    end

    class CreateCategory
      REQUIRED_SCOPES = [Scopes::CATEGORIES_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      MAX_NAME_LENGTH = 50
      MAX_DESCRIPTION_LENGTH = CategoryCreator::MAX_DESCRIPTION_LENGTH
      MAX_STYLE_VALUE_LENGTH = 100
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER_OR_NULL,
          slug: OutputSchema::STRING_OR_NULL,
          name: OutputSchema::STRING,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        CategorySupport.ensure_parent_allowed!(arguments, request_context)
        category = CategoryCreator.create(guardian, category_attributes(arguments))
        if !category.persisted?
          message =
            category.errors.full_messages.to_sentence.presence ||
              I18n.t("mcp.errors.category_create_failed")
          raise ToolError, message
        end

        # The request's policy resolved its category sets before this category
        # existed, so the new one is judged against the rules as stored now. A
        # category created where agents can't see is returned without its id.
        if request_context.content_policy.restricts_forum? &&
             !ContentPolicy.load.allows_category_id?(category.id)
          return ToolHelpers.text_and_structured(id: nil, slug: nil, name: category.name)
        end

        ToolHelpers.text_and_structured(id: category.id, slug: category.slug, name: category.name)
      end

      def self.category_attributes(arguments)
        CategorySupport.basic_attributes(arguments).except("slug")
      end
      private_class_method :category_attributes
    end

    class GetCategory
      REQUIRED_SCOPES = [Scopes::CATEGORIES_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(category: CategorySupport::CATEGORY_SCHEMA)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        category = CategorySupport.find_category!(arguments.fetch("category_id"), request_context)
        guardian.ensure_can_edit!(category)
        ToolHelpers.text_and_structured(
          category: CategorySupport.category_json(category, request_context),
        )
      end
    end

    class UpdateCategory
      REQUIRED_SCOPES = [Scopes::CATEGORIES_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      MAX_NAME_LENGTH = CreateCategory::MAX_NAME_LENGTH
      MAX_DESCRIPTION_LENGTH = CategoryUpdater::MAX_DESCRIPTION_LENGTH
      MAX_STYLE_VALUE_LENGTH = CreateCategory::MAX_STYLE_VALUE_LENGTH
      OUTPUT_SCHEMA = OutputSchema.object(category: CategorySupport::CATEGORY_SCHEMA)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        category = CategorySupport.find_category!(arguments.fetch("category_id"), request_context)
        attributes = CategorySupport.basic_attributes(arguments)
        raise ToolError, I18n.t("mcp.errors.category_update_required") if attributes.empty?
        # Moving a category can carry its topics into or out of a restricted
        # subtree, so agents can't re-parent while a rule narrows topics.
        if attributes.key?("parent_category_id") && request_context.content_policy.restricts_forum?
          raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
        end

        if !CategoryUpdater.update(guardian, category, attributes)
          message =
            category.errors.full_messages.to_sentence.presence ||
              I18n.t("mcp.errors.category_update_failed")
          raise ToolError, message
        end

        ToolHelpers.text_and_structured(
          category: CategorySupport.category_json(category, request_context),
        )
      end
    end

    class DeleteCategory
      REQUIRED_SCOPES = [Scopes::CATEGORIES_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(deleted: OutputSchema::BOOLEAN, category_id: OutputSchema::INTEGER)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        category = CategorySupport.find_category!(arguments.fetch("category_id"), request_context)
        guardian.ensure_can_delete!(category)

        if arguments["confirm"] != true
          raise ToolError, I18n.t("mcp.errors.category_delete_confirmation_required")
        end
        if arguments.fetch("expected_name") != category.name
          raise ToolError, I18n.t("mcp.errors.category_delete_name_mismatch")
        end

        category_id = category.id
        CategoryDestroyer.destroy(guardian, category)
        ToolHelpers.text_and_structured(deleted: true, category_id:)
      end
    end
  end
end
