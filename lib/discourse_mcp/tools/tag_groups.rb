# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module TagGroupSupport
      TAG_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          name: OutputSchema::STRING,
          slug: OutputSchema::STRING,
        )
      GROUP_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          name: OutputSchema::STRING,
          tags: {
            type: "array",
            items: TAG_SCHEMA,
          },
          parent_tag: {
            type: "array",
            items: TAG_SCHEMA,
          },
          one_per_topic: OutputSchema::BOOLEAN,
          permissions: OutputSchema::OBJECT,
        )
      ATTRIBUTES = %w[name tags parent_tag one_per_topic permissions].freeze

      module_function

      def find!(guardian, id)
        guardian.ensure_can_admin_tag_groups!
        TagGroup.find_by(id:) || raise(ToolError, I18n.t("mcp.errors.tag_group_not_found"))
      end

      def json(group)
        TagGroupSerializer.new(group, root: false).as_json
      end

      def attributes(arguments)
        attributes = arguments.slice(*ATTRIBUTES).deep_dup
        attributes["parent_tag"] = Array.wrap(attributes["parent_tag"]) if attributes.key?(
          "parent_tag",
        )
        selectors = Array(attributes["tags"]) + Array(attributes["parent_tag"])
        named_selectors = selectors.select { |selector| selector.key?("name") }
        if named_selectors.present? && arguments["allow_tag_creation"] != true
          raise ToolError, I18n.t("mcp.errors.tag_group_tag_creation_confirmation")
        end
        ids = selectors.filter_map { |selector| selector["id"] }.uniq
        tags = Tag.where(id: ids)
        if named_selectors.present?
          names =
            named_selectors.flat_map do |selector|
              [selector["name"], DiscourseTagging.clean_tag(selector["name"])]
            end
          tags = tags.or(Tag.where_name(names.uniq))
        end
        tags = tags.pluck(:id, :name, :target_tag_id)
        canonical_ids = tags.to_h { |id, _name, target_id| [id, target_id || id] }
        if (ids - canonical_ids.keys).present?
          raise ToolError, I18n.t("mcp.errors.tag_group_unknown_tags")
        end
        canonical_ids_by_name = tags.to_h { |id, name, target_id| [name.downcase, target_id || id] }
        if named_selectors.any? { |selector|
             !canonical_ids_by_name.key?(selector["name"].downcase) &&
               DiscourseTagging.clean_tag(selector["name"]).blank?
           }
          raise ToolError, I18n.t("mcp.errors.tag_group_tags_unresolved")
        end
        resolved_tag_ids =
          selectors
            .filter_map do |selector|
              resolved_id =
                if selector.key?("id")
                  canonical_ids.fetch(selector["id"])
                else
                  canonical_ids_by_name.fetch(selector["name"].downcase) do
                    canonical_ids_by_name[DiscourseTagging.clean_tag(selector["name"]).downcase]
                  end
                end
              next unless resolved_id
              selector.replace("id" => resolved_id)
              resolved_id
            end
            .uniq
        if resolved_tag_ids.present? &&
             Tag.base_tags.where(id: resolved_tag_ids).count != resolved_tag_ids.length
          raise ToolError, I18n.t("mcp.errors.tag_group_unknown_tags")
        end
        if attributes["permissions"]
          ids = attributes["permissions"].keys.map(&:to_i) - [Group::AUTO_GROUPS[:everyone]]
          if Group.where(id: ids).count != ids.length
            raise ToolError, I18n.t("mcp.errors.tag_group_unknown_permission_groups")
          end
        end
        attributes
      end
    end

    class SearchTagGroups
      REQUIRED_SCOPES = [Scopes::CONTENT_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          results: {
            type: "array",
            items:
              OutputSchema.object(
                name: OutputSchema::STRING,
                tags: {
                  type: "array",
                  items: TagGroupSupport::TAG_SCHEMA,
                },
              ),
          },
          limit: OutputSchema::INTEGER,
          truncated: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        limit = arguments.fetch("limit", 100)
        results =
          TagGroupSearch.search(
            request_context.guardian,
            q: arguments["q"],
            names: arguments["names"],
            limit:,
          )
        ToolHelpers.text_and_structured(results:, limit:, truncated: results.length == limit)
      end
    end

    class ListTagGroups
      REQUIRED_SCOPES = [Scopes::TAG_GROUPS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          tag_groups: {
            type: "array",
            items: TagGroupSupport::GROUP_SCHEMA,
          },
          has_more: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_staff!
        limit = arguments.fetch("limit", 100)
        groups =
          TagGroup
            .order(:name, :id)
            .offset(arguments.fetch("offset", 0))
            .limit(limit + 1)
            .preload(:parent_tag, :base_tags, :tag_group_permissions)
            .to_a
        ToolHelpers.text_and_structured(
          tag_groups: groups.first(limit).map { |group| TagGroupSupport.json(group) },
          has_more: groups.length > limit,
        )
      end
    end

    class GetTagGroup
      REQUIRED_SCOPES = [Scopes::TAG_GROUPS_READ].freeze
      OUTPUT_SCHEMA = OutputSchema.object(tag_group: TagGroupSupport::GROUP_SCHEMA)

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_staff!
        group = TagGroup.find_by(id: arguments.fetch("tag_group_id"))
        raise ToolError, I18n.t("mcp.errors.tag_group_not_found") unless group
        ToolHelpers.text_and_structured(tag_group: TagGroupSupport.json(group))
      end
    end

    class CreateTagGroup
      REQUIRED_SCOPES = [Scopes::TAG_GROUPS_WRITE].freeze
      OUTPUT_SCHEMA = GetTagGroup::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_can_admin_tag_groups!
        group = TagGroupCreator.create(guardian, TagGroupSupport.attributes(arguments))
        raise ToolError, group.errors.full_messages.to_sentence unless group.persisted?
        ToolHelpers.text_and_structured(tag_group: TagGroupSupport.json(group))
      end
    end

    class UpdateTagGroup
      REQUIRED_SCOPES = [Scopes::TAG_GROUPS_WRITE].freeze
      OUTPUT_SCHEMA = GetTagGroup::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = TagGroupSupport.find!(guardian, arguments.fetch("tag_group_id"))
        attributes = TagGroupSupport.attributes(arguments)
        raise ToolError, I18n.t("mcp.errors.tag_group_update_required") if attributes.empty?
        unless TagGroupUpdater.update(guardian, group, attributes, partial: true)
          raise ToolError, group.errors.full_messages.to_sentence
        end
        ToolHelpers.text_and_structured(tag_group: TagGroupSupport.json(group.reload))
      end
    end

    class DeleteTagGroup
      REQUIRED_SCOPES = [Scopes::TAG_GROUPS_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(deleted: OutputSchema::BOOLEAN, tag_group_id: OutputSchema::INTEGER)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = TagGroupSupport.find!(guardian, arguments.fetch("tag_group_id"))
        TagGroup.transaction do
          group.lock!
          unless arguments["confirm"] == true && arguments["expected_name"] == group.name
            raise ToolError, I18n.t("mcp.errors.tag_group_delete_confirmation")
          end
          TagGroupDestroyer.destroy(guardian, group)
        end
        ToolHelpers.text_and_structured(deleted: true, tag_group_id: group.id)
      end
    end
  end
end
