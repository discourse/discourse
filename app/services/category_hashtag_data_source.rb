# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide category
# results when looking up a category slug via markdown or searching for
# categories via the # autocomplete character.
class CategoryHashtagDataSource
  def self.enabled?
    true
  end

  def self.icon
    "folder"
  end

  def self.type
    "category"
  end

  def self.category_to_hashtag_item(category)
    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text =
        (
          if category.parent_category
            "#{category.parent_category.name} > #{category.name}"
          else
            category.name
          end
        )
      item.slug = category.slug
      item.description = category.description_text
      item.colors = [category.parent_category&.color, category.color].compact
      item.relative_url = category.url
      item.id = category.id
      item.style_type = category.style_type
      item.icon = category.style_type == "icon" ? category.icon : icon
      item.emoji = category.emoji if category.style_type == "emoji"

      # Single-level category hierarchy should be enough to distinguish between
      # categories here.
      item.ref = category.slug_ref
    end
  end

  def self.find_by_ids(guardian, ids)
    Category.secured(guardian).where(id: ids).map { |category| category_to_hashtag_item(category) }
  end

  def self.lookup(guardian, slugs)
    user_categories =
      Category
        .secured(guardian)
        .includes(:parent_category)
        .order("parent_category_id ASC NULLS FIRST, id ASC")
    Category
      .query_loaded_from_slugs(slugs, user_categories)
      .map { |category| category_to_hashtag_item(category) }
  end

  def self.search(
    guardian,
    term,
    limit,
    condition = HashtagAutocompleteService.search_conditions[:contains]
  )
    base_search =
      Category
        .secured(guardian)
        .select(
          :id,
          :parent_category_id,
          :slug,
          :name,
          :description,
          :color,
          :style_type,
          :icon,
          :emoji,
        )
        .includes(:parent_category)

    if condition == HashtagAutocompleteService.search_conditions[:starts_with]
      base_search = base_search.where("starts_with(LOWER(slug), LOWER(:term))", term: term)
    elsif condition == HashtagAutocompleteService.search_conditions[:contains]
      base_search =
        base_search.where(
          "position(LOWER(:term) IN LOWER(name)) <> 0 OR position(LOWER(:term) IN LOWER(slug)) <> 0",
          term: term,
        )
    else
      raise Discourse::InvalidParameters.new("Unknown search condition: #{condition}")
    end

    base_search.take(limit).map { |category| category_to_hashtag_item(category) }
  end

  def self.search_sort(search_results, term)
    if term.present?
      search_results.sort_by { |item| [item.slug == term ? 0 : 1, item.text.downcase] }
    else
      search_results.sort_by { |item| item.text.downcase }
    end
  end

  def self.search_without_term(guardian, limit)
    Category
      .includes(:parent_category)
      .secured(guardian)
      .where(
        "categories.id NOT IN (#{
          CategoryUser
            .muted_category_ids_query(guardian.user, include_direct: true)
            .select("categories.id")
            .to_sql
        })",
      )
      .order(topic_count: :desc)
      .take(limit)
      .map { |category| category_to_hashtag_item(category) }
  end
end
