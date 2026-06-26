# frozen_string_literal: true

class Admin::Config::CategoryManagementController < Admin::AdminController
  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100

  def categories
    type_id = params[:type].presence || "discussion"
    type = Categories::TypeRegistry.get(type_id)

    raise Discourse::NotFound if type.blank?

    categories = categories_for_type(type).includes(:parent_category)
    categories = filter_categories(categories, params[:filter]) if params[:filter].present?
    categories = filter_by_visibility(categories, params[:visibility]) if params[
      :visibility
    ].present?

    per_page =
      params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_PER_PAGE) : DEFAULT_PER_PAGE
    page = [params[:page].to_i, 0].max

    categories = categories.order(Category.normalize_sql("categories.name"), "categories.id ASC")
    paginated_categories = categories.offset(page * per_page).limit(per_page + 1).to_a
    has_more = paginated_categories.length > per_page
    paginated_categories = paginated_categories.take(per_page)

    render_json_dump(
      categories: paginated_categories.map { |category| serialize_category(category) },
      has_more: has_more,
    )
  end

  private

  def categories_for_type(type)
    categories = Category.secured(guardian)

    if type.type_id == :discussion
      categories
    else
      categories.where(id: type.find_matches.select(:id))
    end
  end

  def filter_categories(categories, filter)
    filter = filter.to_s.strip.delete_prefix("#")
    return categories if filter.blank?

    normalized_search =
      filter.tr("/", Category::SLUG_REF_SEPARATOR).gsub(
        /#{Regexp.escape(Category::SLUG_REF_SEPARATOR)}+/,
        Category::SLUG_REF_SEPARATOR,
      )
    normalized_filter = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_search)}%"

    categories.where(
      "#{Category.normalize_sql("categories.name")} ILIKE #{Category.normalize_sql("?")} OR " \
        "#{Category.normalize_sql("categories.slug")} ILIKE #{Category.normalize_sql("?")} OR " \
        "EXISTS (
          SELECT 1
          FROM categories parent_categories
          WHERE parent_categories.id = categories.parent_category_id
            AND #{Category.normalize_sql("parent_categories.slug || '#{Category::SLUG_REF_SEPARATOR}' || categories.slug")} ILIKE #{Category.normalize_sql("?")}
        )",
      normalized_filter,
      normalized_filter,
      normalized_filter,
    )
  end

  def filter_by_visibility(categories, visibility)
    case visibility
    when "public"
      categories.where(read_restricted: false)
    when "restricted"
      categories.where(read_restricted: true)
    else
      categories
    end
  end

  def serialize_category(category)
    {
      id: category.id,
      badge_chain: badge_chain(category),
      description_text: category.description_text,
      read_restricted: category.read_restricted,
      topic_count: category.topic_count,
      edit_url: "#{category.slug_url_without_id}/edit/general",
    }
  end

  def badge_chain(category)
    ancestors(category)
      .push(category)
      .map { |badge_category| serialize_badge_category(badge_category) }
  end

  def ancestors(category)
    ancestors = []
    parent = category.parent_category

    while parent.present?
      ancestors.unshift(parent)
      parent = parent.parent_category
    end

    ancestors
  end

  def serialize_badge_category(category)
    {
      id: category.id,
      name: category.uncategorized? ? I18n.t("uncategorized_category_name") : category.name,
      slug: category.slug,
      color: category.color,
      text_color: category.text_color,
      style_type: category.style_type,
      icon: category.icon,
      emoji: category.emoji,
      read_restricted: category.read_restricted,
      parent_category_id: category.parent_category_id,
    }
  end
end
