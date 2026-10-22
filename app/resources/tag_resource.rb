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

  # Names are unique whatever the case, so this finds at most one tag per name. Pickers read it
  # beside the term search to list the exact match first.
  NAME = ->(scope, value) { scope.where_name(value) }

  TERM =
    lambda do |scope, value|
      pattern = "%#{Tag.sanitize_sql_like(value)}%"
      localized_ids =
        DiscourseTagging.tag_ids_matching_localizations(
          value,
          term_type: DiscourseTagging.term_types[:contains],
        )
      scope.where(Tag.arel_table[:name].matches(pattern)).or(scope.where(id: localized_ids))
    end

  EXCLUDE_SYNONYMS =
    lambda do |scope, value|
      ActiveModel::Type::Boolean.new.cast(value) ? scope.where(target_tag_id: nil) : scope
    end

  EXCLUDE_HAS_SYNONYMS =
    lambda do |scope, value|
      if ActiveModel::Type::Boolean.new.cast(value)
        scope.where.not(id: Tag.where.not(target_tag_id: nil).select(:target_tag_id))
      else
        scope
      end
    end

  filter :id
  filter(:name, &NAME)
  filter(:term, &TERM)
  filter(:exclude_synonyms, &EXCLUDE_SYNONYMS)
  filter(:exclude_has_synonyms, &EXCLUDE_HAS_SYNONYMS)

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

  # The tags a guardian may apply to a topic. The rules apply to every request: a request without
  # a category asks for a topic without one, and one without held tags for a topic holding none.
  collection :applicable do
    scope_filter :category, default: nil
    scope_filter :held, default: []
    filter(:name, &NAME)
    filter(:term, &TERM)
    filter(:exclude_synonyms, &EXCLUDE_SYNONYMS)
    filter(:exclude_has_synonyms, &EXCLUDE_HAS_SYNONYMS)

    # Admins are narrowed to a required group only while they have not typed a term, so the
    # input scope reads the term as well as filtering by it.
    input_scope do |tags, guardian, category:, held:, term: nil|
      InputRules
        .new(
          guardian:,
          category: InputRules.category_for(guardian, category),
          held_ids: held,
          term:,
        )
        .apply(tags)
        .where.not(id: held)
    end
  end
end
