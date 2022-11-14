# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide category
# results when looking up a category slug via markdown or searching for
# categories via the # autocomplete character.
class CategoryHashtagDataSource
  def self.icon
    "folder"
  end

  def self.category_to_hashtag_item(guardian_categories, category)
    category = Category.new(category.slice(:id, :slug, :name, :parent_category_id)) if category.is_a?(Hash)

    HashtagAutocompleteService::HashtagItem.new.tap do |item|
      item.text = category.name
      item.slug = category.slug
      item.icon = icon
      item.url = category.url

      # Single-level category heirarchy should be enough to distinguish between
      # categories here.
      item.ref =
        if category.parent_category_id
          parent_category =
            guardian_categories.find { |gc| gc[:id] === category.parent_category_id }
          category.slug if !parent_category

          parent_slug = parent_category[:slug]
          "#{parent_slug}:#{category.slug}"
        else
          category.slug
        end
    end
  end

  def self.lookup(guardian, slugs)
    guardian_categories = Site.new(guardian).categories
    category_slugs_and_ids =
      slugs.map { |slug| [slug, Category.query_from_hashtag_slug(slug)&.id] }.to_h
    Category
      .secured(guardian)
      .select(:id, :slug, :name, :parent_category_id)
      .where(id: category_slugs_and_ids.values)
      .map { |category| category_to_hashtag_item(guardian_categories, category) }
  end

  def self.search(guardian, term, limit)
    guardian_categories = Site.new(guardian).categories

    guardian_categories
      .select { |category| category[:name].downcase.include?(term) }
      .take(limit)
      .map { |category| category_to_hashtag_item(guardian_categories, category) }
  end
end
