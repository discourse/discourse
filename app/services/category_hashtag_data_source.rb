# frozen_string_literal: true

# Used as a data source via HashtagAutocompleteService to provide category
# results when looking up a category slug via markdown or searching for
# categories via the # autocomplete character.
class CategoryHashtagDataSource
  def self.lookup(guardian, slugs)
    category_slugs_and_ids =
      slugs.map { |slug| [slug, Category.query_from_hashtag_slug(slug)&.id] }.to_h
    Category
      .secured(guardian)
      .select(:id, :slug, :name, :parent_category_id) # fields required for generating category URL
      .where(id: category_slugs_and_ids.values)
      .map do |c|
        HashtagAutocompleteService::HashtagItem.new.tap do |item|
          item.text = c.name
          item.slug = c.slug
          item.icon = "folder"
          item.url = c.url
        end
      end
    # .map { |c| [c.id, c.url] }
    # .to_h
    # categories_hashtags = {}
    # category_slugs_and_ids.each do |slug, id|
    #   if category_url = category_ids_and_urls[id]
    #     categories_hashtags[slug] = category_url
    #   end
    # end

    # categories_hashtags
  end

  def self.search(guardian, term, limit)
    guardian_categories = Site.new(guardian).categories

    guardian_categories
      .select { |category| category[:name].downcase.include?(term) }
      .take(limit)
      .map do |category|
        HashtagAutocompleteService::HashtagItem.new.tap do |item|
          item.text = category[:name]
          item.slug = category[:slug]

          # Single-level category heirarchy should be enough to distinguish between
          # categories here.
          item.ref =
            if category[:parent_category_id]
              parent_category =
                guardian_categories.find { |c| c[:id] === category[:parent_category_id] }
              category[:slug] if !parent_category

              parent_slug = parent_category[:slug]
              "#{parent_slug}:#{category[:slug]}"
            else
              category[:slug]
            end
          item.icon = "folder"
        end
      end
  end
end
