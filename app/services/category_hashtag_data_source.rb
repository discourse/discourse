# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide category
# results when looking up a category slug via markdown or searching for
# categories via the # autocomplete character.
class CategoryHashtagDataSource
  def self.icon
    "folder"
  end

  def self.category_to_hashtag_item(guardian_categories, category)
    category = Category.new(category.slice(:id, :slug, :name, :parent_category_id, :description))

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
          parent_category =
            guardian_categories.find { |cat| cat[:id] === category.parent_category_id }
          !parent_category ? category.slug : "#{parent_category[:slug]}:#{category.slug}"
        else
          category.slug
        end
    end
  end

  def self.lookup(guardian, slugs)
    # We use Site here because it caches all the categories the
    # user has access to.
    guardian_categories = Site.new(guardian).categories
    Category
      .query_from_cached_categories(slugs, guardian_categories)
      .map { |category| category_to_hashtag_item(guardian_categories, category) }
  end

  def self.search(guardian, term, limit)
    guardian_categories = Site.new(guardian).categories

    guardian_categories
      .select do |category|
        category[:name].downcase.include?(term) || category[:slug].downcase.include?(term)
      end
      .take(limit)
      .map { |category| category_to_hashtag_item(guardian_categories, category) }
  end

  def self.search_sort(search_results, term)
    if term.present?
      search_results
        .select { |item| item.slug == term }
        .sort_by { |item| item.text.downcase }
        .concat(
          search_results.select { |item| item.slug != term }.sort_by { |item| item.text.downcase },
        )
    else
      search_results.sort_by { |item| item.text.downcase }
    end
  end

  def self.search_without_term(guardian, limit)
    guardian_categories = Site.new(guardian).categories

    category_id_sql = <<~SQL
      SELECT category_id, MAX(posts.created_at)
      FROM topics
      INNER JOIN posts ON posts.topic_id = topics.id
      WHERE topics.deleted_at IS NULL
        AND posts.deleted_at IS NULL
        AND posts.created_at > (NOW() - INTERVAL '2 WEEKS')
        AND topics.category_id IN (:category_ids)
      GROUP BY category_id
      ORDER BY MAX(posts.created_at) DESC
      LIMIT :limit
    SQL
    category_ids =
      DB.query(
        category_id_sql,
        category_ids: guardian_categories.map { |cat| cat[:id] },
        limit: limit,
      ).map(&:category_id)

    guardian_categories
      .select { |category| category_ids.include?(category[:id]) }
      .take(limit)
      .map { |category| category_to_hashtag_item(guardian_categories, category) }
  end
end
