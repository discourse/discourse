# frozen_string_literal: true

class CategoryHierarchicalSearch
  include Service::Base

  params do
    attribute :term, :string, default: ""
    attribute :only_ids, :array, default: [], compact_blank: true
    attribute :except_ids, :array, default: [], compact_blank: true
    attribute :limit, :integer
    attribute :offset, :integer

    after_validation { self.term = term.to_s.strip }
  end

  model :categories, optional: true
  step :eager_load_associations

  private

  def fetch_categories(guardian:, params:)
    query_params = { offset: params.offset, limit: params.limit, term: params.term }
    query_params[:only_ids] = params.only_ids if params.only_ids.present?
    query_params[:except_ids] = params.except_ids if params.except_ids.present?

    allowed_categories_sql =
      Category
        .secured(guardian)
        .select(:id, :name, :parent_category_id)
        .where("id <> ?", SiteSetting.uncategorized_category_id)
        .to_sql

    matches_sql =
      if query_params[:term].present?
        <<~SQL
          (
            starts_with(LOWER(name), LOWER(:term))
            OR COALESCE(
              (
                SELECT BOOL_AND(position(pattern IN LOWER(allowed_categories.name)) <> 0)
                FROM unnest(regexp_split_to_array(LOWER(:term), '\\s+')) AS pattern
              ),
              true
            )
          )
        SQL
      else
        "TRUE"
      end

    only_ids_sql =
      if query_params[:only_ids].present?
        "AND allowed_categories.id IN (:only_ids)"
      else
        ""
      end

    except_ids_sql =
      if query_params[:except_ids].present?
        "AND allowed_categories.id NOT IN (:except_ids)"
      else
        ""
      end

    # Note that we are setting the `allowed_categories` CTE as `NOT MATERIALIZED` since materializing the CTE degrades
    # performance of the query significantly on sites with a large number of rows in the categories table
    sql = <<~SQL
      WITH RECURSIVE
      allowed_categories AS NOT MATERIALIZED (
        #{allowed_categories_sql}
      ),
      matched AS (
        SELECT id
        FROM allowed_categories
        WHERE
          #{matches_sql}
          #{only_ids_sql}
          #{except_ids_sql}
      ),
      matched_with_ancestors AS (
        SELECT c.id, c.parent_category_id
        FROM allowed_categories c
        JOIN matched m ON m.id = c.id

        UNION ALL

        SELECT p.id, p.parent_category_id
        FROM allowed_categories p
        JOIN matched_with_ancestors a ON a.parent_category_id = p.id
      ),
      category_tree AS (
        SELECT
          c.id,
          c.parent_category_id,
          c.name,
          ARRAY[lower(c.name)]::text[] AS name_path,
          0 AS depth
        FROM allowed_categories c
        WHERE c.parent_category_id IS NULL

        UNION ALL

        SELECT
          c.id,
          c.parent_category_id,
          c.name,
          ct.name_path || lower(c.name),
          ct.depth + 1
        FROM allowed_categories c
        JOIN category_tree ct ON c.parent_category_id = ct.id
      )
      SELECT
        categories.*
      FROM category_tree ct
      INNER JOIN categories ON categories.id = ct.id
      INNER JOIN (SELECT DISTINCT id FROM matched_with_ancestors) a ON a.id = ct.id
      ORDER BY ct.name_path, ct.id
      #{params.limit.present? ? "LIMIT :limit" : ""}
      #{params.offset.present? ? "OFFSET :offset" : ""}
    SQL

    Category.find_by_sql([sql, query_params])
  end

  def eager_load_associations
    ActiveRecord::Associations::Preloader.new(
      records: context.categories,
      associations: [
        :uploaded_logo,
        :uploaded_logo_dark,
        :uploaded_background,
        :uploaded_background_dark,
        :tags,
        :tag_groups,
        :form_templates,
        { category_required_tag_groups: :tag_group },
      ],
    ).call

    if Site.preloaded_category_custom_fields.present?
      Category.preload_custom_fields(context.categories, Site.preloaded_category_custom_fields)
    end

    Category.preload_user_fields!(context.guardian, context.categories)
  end
end
