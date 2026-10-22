# frozen_string_literal: true

class TagResource
  # Relation clauses for the tags a guardian may apply to a topic. They mirror
  # `DiscourseTagging.filter_allowed_tags(for_input: true)` without its raw SQL builder, so they
  # compose with the resource's other filters and with keyset pagination.
  class InputRules
    MEMBERSHIPS_SQL = <<~SQL
      LEFT JOIN tag_group_memberships tgm ON tgm.tag_id = tags.id
      LEFT JOIN tag_groups tg ON tg.id = tgm.tag_group_id
    SQL

    RESTRICTIONS_SQL = <<~SQL
      (
        EXISTS (SELECT 1 FROM category_tags ct WHERE ct.tag_id = tags.id %{category})
        OR EXISTS (
          SELECT 1 FROM category_tag_groups ctg
          WHERE ctg.tag_group_id = tgm.tag_group_id %{category}
        )
      )
    SQL

    # What the rules need to know about a category, read in one query.
    ResolvedCategory =
      Data.define(:id, :allow_global_tags, :tag_groups, :tags, :required_groups) do
        def restricted? = tag_groups || tags
      end

    # A required tag group, in the category's order, with the ids of its tags.
    RequiredGroup = Data.define(:tag_ids, :min_count)

    CATEGORY_COLUMNS =
      [
        "categories.id",
        "categories.allow_global_tags",
        "EXISTS (SELECT 1 FROM category_tag_groups ctg WHERE ctg.category_id = categories.id)",
        "EXISTS (SELECT 1 FROM category_tags ct WHERE ct.category_id = categories.id)",
        <<~SQL,
        (
          SELECT COALESCE(
            json_agg(
              json_build_object(
                'min_count', crtg.min_count,
                'tag_ids', (
                  SELECT COALESCE(json_agg(tgm.tag_id), '[]')
                  FROM tag_group_memberships tgm
                  WHERE tgm.tag_group_id = crtg.tag_group_id
                )
              )
              ORDER BY crtg."order", crtg.id
            ),
            '[]'
          )
          FROM category_required_tag_groups crtg
          WHERE crtg.category_id = categories.id
        )
      SQL
      ].map { Arel.sql(it) }.freeze

    # Resolves a requested category the way tag search does: one the guardian cannot see counts as
    # no category at all.
    def self.category_for(guardian, id)
      return if id.blank?
      row = ::Category.where(id: guardian.allowed_category_ids).where(id:).pick(*CATEGORY_COLUMNS)
      return if row.nil?

      id, allow_global_tags, tag_groups, tags, required = row
      required = JSON.parse(required) if required.is_a?(String)
      ResolvedCategory.new(
        id:,
        allow_global_tags:,
        tag_groups:,
        tags:,
        required_groups:
          required.map { RequiredGroup.new(tag_ids: it["tag_ids"], min_count: it["min_count"]) },
      )
    end

    # The category restriction alone, as tag search applies it outside an input.
    def self.within_category(scope, category)
      return scope if category.nil?
      condition =
        new(guardian: nil, category:, held_ids: [], term: nil).category_condition(for_input: false)
      scope.where(id: memberships.where(condition).select("tags.id"))
    end

    def self.memberships = Tag.unscoped.joins(MEMBERSHIPS_SQL)

    def initialize(guardian:, category:, held_ids:, term:)
      @guardian = guardian
      @category = category
      @held_ids = Array.wrap(held_ids).map(&:to_i)
      @term = term
    end

    def apply(scope)
      scope = scope.where(id: usable_memberships.select("tags.id"))
      scope = within_required_group(scope)
      without_other_one_per_topic_tags(scope)
    end

    def category_condition(for_input:)
      if category&.restricted?
        within = format(RESTRICTIONS_SQL, category: "AND category_id = #{category.id.to_i}")
        category.allow_global_tags ? "#{within} OR NOT #{unrestricted_sql}" : within
      elsif category || for_input
        "NOT #{unrestricted_sql}"
      end
    end

    private

    attr_reader :guardian, :category, :held_ids, :term

    def non_admin? = !guardian.is_admin?

    def unrestricted_sql = format(RESTRICTIONS_SQL, category: "")

    # The parent-tag, staff-only and category rules must hold for the same group membership, so
    # a tag in several groups is usable when any one of its memberships passes all three.
    def usable_memberships
      rows = self.class.memberships.where(parent_condition, held_ids:)
      rows = rows.where(category_condition(for_input: true))
      return rows unless non_admin?
      rows.where(<<~SQL, full: TagGroupPermission.permission_types[:full])
        tgm.tag_group_id IS NULL OR tgm.tag_group_id IN (
          SELECT tag_group_id FROM tag_group_permissions
          WHERE permission_type = :full AND group_id IN (#{permitted_group_ids_sql})
        )
      SQL
    end

    def parent_condition
      return "tg.parent_tag_id IS NULL" if held_ids.empty?
      "tg.parent_tag_id IS NULL OR tg.parent_tag_id IN (:held_ids)"
    end

    def permitted_group_ids_sql = DiscourseTagging.permitted_group_ids_query(guardian).to_sql

    # Narrows to the first required group still short of its minimum. Staff only get the narrowing
    # while they haven't typed a term.
    def within_required_group(scope)
      return scope if category.nil?
      return scope unless non_admin? || term.blank?

      category.required_groups.each do |required|
        next if (required.tag_ids & held_ids).size >= required.min_count
        return scope.where(id: required.tag_ids)
      end
      scope
    end

    def without_other_one_per_topic_tags(scope)
      return scope if held_ids.empty?

      groups =
        TagGroup.where(one_per_topic: true).where(
          id: TagGroupMembership.where(tag_id: held_ids).select(:tag_group_id),
        )
      if category&.tag_groups
        in_category = CategoryTagGroup.where(category_id: category.id).select(:tag_group_id)
        groups =
          if category.allow_global_tags
            groups.where(id: in_category).or(
              groups.where.not(id: CategoryTagGroup.select(:tag_group_id)),
            )
          else
            groups.where(id: in_category)
          end
      end

      scope.where.not(
        id:
          TagGroupMembership
            .where(tag_group_id: groups.select(:id))
            .where.not(tag_id: held_ids)
            .select(:tag_id),
      )
    end
  end
end
