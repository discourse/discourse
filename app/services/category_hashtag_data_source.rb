# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide category
# results when looking up a category slug via markdown or searching for
# categories via the # autocomplete character.
class CategoryHashtagDataSource
  def self.icon
    "folder"
  end

  def self.category_to_hashtag_item(category)
    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text = category.name
      item.slug = category.slug
      item.description = category.description_text
      item.icon = icon
      item.relative_url = category.url

      # Single-level category heirarchy should be enough to distinguish between
      # categories here.
      item.ref =
        if category.parent_category_id
          "#{category.parent_category.slug}:#{category.slug}"
        else
          category.slug
        end
    end
  end

  def self.lookup(guardian, slugs)
    user_categories = Category.secured(guardian).includes(:parent_category)
    Category
      .query_loaded_from_slugs(slugs, user_categories)
      .map { |category| category_to_hashtag_item(category) }
  end

  def self.search(guardian, term, limit)
    Category
      .secured(guardian)
      .includes(:parent_category)
      .where("LOWER(name) LIKE :term OR LOWER(slug) LIKE :term", term: "%#{term}%")
      .take(limit)
      .map { |category| category_to_hashtag_item(category) }
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
      .joins(
        "LEFT JOIN category_users ON category_users.user_id = #{guardian.user.id}
        AND category_users.category_id = categories.id",
      )
      .where(
        "category_users.notification_level IS NULL OR category_users.notification_level != ?",
        CategoryUser.notification_levels[:muted],
      )
      .order(topic_count: :desc)
      .take(limit)
      .map { |category| category_to_hashtag_item(category) }
  end
end
