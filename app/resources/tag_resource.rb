# frozen_string_literal: true

class TagResource < JsonApiKit::Resource
  # Staff counts include topics in secure categories. Whoever may read them may also sort by them,
  # since cursors carry the sorted values. Mirrors `Tag.topic_count_column`.
  STAFF_COUNTS_READABLE = ->(guardian) do
    guardian.is_staff? || SiteSetting.include_secure_categories_in_tag_counts
  end

  scope { |guardian| DiscourseTagging.visible_tags(guardian) }

  attribute :name
  attribute :slug
  attribute :description
  attribute :public_topic_count
  attribute :staff_topic_count, readable: STAFF_COUNTS_READABLE

  has_one :target_tag, resource: TagResource

  sort :name
  sort :public_topic_count
  sort :staff_topic_count, readable: STAFF_COUNTS_READABLE
  default_sort public_topic_count: :desc

  page default: 20, max: 100

  filter :id

  # Names are unique whatever the case, so this finds at most one tag per name. Pickers read it
  # beside the term search to list the exact match first.
  filter(:name) { |scope, value| scope.where_name(value) }

  filter :term do |scope, value|
    pattern = "%#{Tag.sanitize_sql_like(value)}%"
    localized_ids =
      DiscourseTagging.tag_ids_matching_localizations(
        value,
        term_type: DiscourseTagging.term_types[:contains],
      )
    scope.where(Tag.arel_table[:name].matches(pattern)).or(scope.where(id: localized_ids))
  end

  filter :exclude do |scope, value|
    scope.where.not(id: value)
  end

  # Keeps the set only; listings order by the declared sorts, so recency itself is not kept.
  filter :recently_used do |scope, value, context|
    next scope unless ActiveModel::Type::Boolean.new.cast(value)
    scope.where(id: Tag.recently_used_by(context.guardian.user))
  end

  filter :category do |scope, value, context|
    InputRules.within_category(scope, InputRules.category_for(context.guardian, value))
  end

  # The held tags travel as `exclude`, so the rules read them, the category and the term from the
  # sibling filters.
  filter :usable_for_input do |scope, value, context|
    next scope unless ActiveModel::Type::Boolean.new.cast(value)

    filtering = context.filtering
    InputRules.new(
      guardian: context.guardian,
      category: InputRules.category_for(context.guardian, filtering["category"]),
      held_ids: filtering["exclude"],
      term: filtering["term"],
    ).apply(scope)
  end

  filter :exclude_synonyms do |scope, value|
    ActiveModel::Type::Boolean.new.cast(value) ? scope.where(target_tag_id: nil) : scope
  end

  filter :exclude_has_synonyms do |scope, value|
    if ActiveModel::Type::Boolean.new.cast(value)
      scope.where.not(id: Tag.where.not(target_tag_id: nil).select(:target_tag_id))
    else
      scope
    end
  end
end
