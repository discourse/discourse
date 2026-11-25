# frozen_string_literal: true

module DiscourseMcp
  # What the admin content restrictions page shows: every registered rule kind
  # with its stored config, the exposed primitives it switches off or filters,
  # and the stored rules whose kind can't be enforced.
  class ContentRestrictionsReport
    # @param registry [DiscourseMcp::Registry]
    def initialize(registry: DiscourseMcp.registry)
      @registry = registry
      @rows = McpContentRule.includes(:updated_by).order(:id).to_a
      @current = ContentPolicy.new(pairs(@rows), registry:)
    end

    # The exposed primitives, the ones enabled, not emergency-blocked and
    # available, that the given policy blocks.
    #
    # @param policy [ContentPolicy]
    # @returns [Array<String>] Primitive ids in the "<kind>:<identifier>" form.
    def blocked_ids(policy)
      exposed.reject { |primitive| policy.allows_primitive?(primitive) }.map { |p| id_of(p) }
    end

    # @returns [Hash]
    def as_json(*)
      {
        rule_kinds: @registry.content_rule_kinds.map { |kind| kind_entry(kind) },
        orphans:
          @rows
            .select { |row| orphan?(row) }
            .map { |row| { rule_kind: row.rule_kind, updated_at: row.updated_at } },
        private_message_scopes_overridden: @current.denies_all?(ContentPolicy::PRIVATE_MESSAGES),
        primitive_titles: exposed.to_h { |primitive| [id_of(primitive), primitive.title] },
      }
    end

    # @param primitive [DiscourseMcp::Primitive]
    # @returns [String]
    def self.id_of(primitive)
      "#{primitive.kind}:#{primitive.identifier}"
    end

    private

    def kind_entry(kind)
      row = @rows.find { |candidate| candidate.rule_kind == kind.name }
      alone = ContentPolicy.new([[kind.name, row&.config || {}]], registry: @registry)
      entry = {
        name: kind.name,
        provider: kind.provider,
        admin_component_id: kind.admin_component_id || kind.name,
        active: row.present?,
        config: row&.config,
        updated_at: row&.updated_at,
        updated_by: row&.updated_by&.username,
        disables: blocked_ids(alone),
        newly_disables: row ? [] : newly_disabled_ids(kind),
        restricts:
          exposed
            .select { |primitive| alone.enforces?(primitive) }
            .map { |primitive| id_of(primitive) },
      }
      entry[:references] = references(row&.config) if kind.name == ForumContentRule::NAME
      entry
    end

    def newly_disabled_ids(kind)
      added = ContentPolicy.new(pairs(@rows) + [[kind.name, {}]], registry: @registry)
      exposed
        .select { |primitive| @current.allows_primitive?(primitive) }
        .reject { |primitive| added.allows_primitive?(primitive) }
        .map { |primitive| id_of(primitive) }
    end

    # The categories and tags a forum config lists, by name, and the listed
    # ids that no longer exist. Subtrees aren't expanded.
    def references(config)
      category_ids = McpContentRule.config_ids(config, "category_ids").to_a
      tag_ids = McpContentRule.config_ids(config, "tag_ids").to_a
      categories = Category.where(id: category_ids).pluck(:id, :name)
      tags = Tag.where(id: tag_ids).pluck(:id, :name)

      {
        categories: categories.map { |id, name| { id:, name: } },
        tags: tags.map { |id, name| { id:, name: } },
        missing_category_ids: category_ids - categories.map(&:first),
        missing_tag_ids: tag_ids - tags.map(&:first),
      }
    end

    def orphan?(row)
      kind = @registry.content_rule_kind(row.rule_kind)
      kind.nil? || !available?(kind)
    end

    def available?(kind)
      kind.available?
    rescue StandardError
      false
    end

    def exposed
      @exposed ||=
        McpPrimitive.exposed.filter_map do |record|
          primitive = @registry.find(record.kind.to_sym, record.identifier)
          primitive if primitive&.available?
        end
    end

    def pairs(rows)
      rows.map { |row| [row.rule_kind, row.config] }
    end

    def id_of(primitive)
      self.class.id_of(primitive)
    end
  end
end
