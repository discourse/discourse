# frozen_string_literal: true

class Category::Query::HierarchicalSearch
  def initialize(guardian:, params:)
    @guardian = guardian
    @params = params
  end

  def call
    build_relation.tap { prepend_allowed_categories_cte(it) }.to_a
  end

  private

  attr_reader :guardian, :params

  def build_relation
    Category
      .with(matched: matched_scope)
      .with_recursive(matched_with_ancestors_cte)
      .with_recursive(category_tree_cte)
      .joins("INNER JOIN category_tree ct ON ct.id = categories.id")
      .joins("INNER JOIN (SELECT DISTINCT id FROM matched_with_ancestors) a ON a.id = ct.id")
      .order("ct.name_path, ct.id")
      .limit(params.limit)
      .offset(params.offset)
  end

  # Prepends the allowed_categories CTE with NOT MATERIALIZED hint.
  # Rails' .with() doesn't support materialization hints, so we manipulate Arel directly.
  # NOT MATERIALIZED prevents PostgreSQL from materializing this CTE, which significantly
  # improves performance on sites with many categories.
  def prepend_allowed_categories_cte(relation)
    cte =
      Arel::Nodes::Cte.new(
        Arel.sql("allowed_categories"),
        allowed_categories_arel,
        materialized: false,
      )
    existing_ctes = relation.arel.ast.with&.children || []
    relation.arel.with(:recursive, [cte] + existing_ctes)
  end

  def allowed_categories_arel
    Category
      .secured(guardian)
      .where.not(id: SiteSetting.uncategorized_category_id)
      .select(:id, :name, :parent_category_id)
      .arel
  end

  def matched_scope
    scope = Category.from("allowed_categories").select(:id)
    scope = scope.where(term_condition) if params.term.present?
    scope = scope.where("id IN (?)", params.only) if params.only.present?
    scope = scope.where("id NOT IN (?)", params.except) if params.except.present?
    scope
  end

  def quoted_term
    @quoted_term ||= Category.normalize_sql(Category.connection.quote(params.term.downcase))
  end

  def term_condition
    Arel.sql(<<~SQL.squish)
      (
    starts_with(#{Category.normalize_sql("name")}, #{quoted_term})
        OR COALESCE(
          (
            SELECT BOOL_AND(position(pattern IN #{Category.normalize_sql("allowed_categories.name")}) <> 0)
            FROM unnest(regexp_split_to_array(#{quoted_term}, '\\s+')) AS pattern
          ),
          true
        )
      )
    SQL
  end

  def matched_with_ancestors_cte
    { matched_with_ancestors: [Arel.sql(<<~SQL), Arel.sql(<<~SQL)] }
          SELECT c.id, c.parent_category_id
          FROM allowed_categories c
          JOIN matched m ON m.id = c.id
        SQL
          SELECT p.id, p.parent_category_id
          FROM allowed_categories p
          JOIN matched_with_ancestors a ON a.parent_category_id = p.id
        SQL
  end

  def category_tree_cte
    { category_tree: [Arel.sql(<<~SQL), Arel.sql(<<~SQL)] }
          SELECT
            c.id,
            c.parent_category_id,
            c.name,
            ARRAY[lower(c.name)]::text[] AS name_path,
            0 AS depth
          FROM allowed_categories c
          WHERE c.parent_category_id IS NULL
        SQL
          SELECT
            c.id,
            c.parent_category_id,
            c.name,
            ct.name_path || lower(c.name),
            ct.depth + 1
          FROM allowed_categories c
          JOIN category_tree ct ON c.parent_category_id = ct.id
        SQL
  end
end
