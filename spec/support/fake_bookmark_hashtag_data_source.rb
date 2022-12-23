# frozen_string_literal: true

class FakeBookmarkHashtagDataSource
  def self.icon
    "bookmark"
  end

  def self.type
    "bookmark"
  end

  def self.lookup(guardian_scoped, slugs)
    guardian_scoped
      .user
      .bookmarks
      .where("LOWER(name) IN (:slugs)", slugs: slugs)
      .map do |bm|
        HashtagAutocompleteService::HashtagItem.new.tap do |item|
          item.text = bm.name
          item.slug = bm.name.gsub(" ", "-")
          item.icon = icon
        end
      end
  end

  def self.search(
    guardian_scoped,
    term,
    limit,
    condition = HashtagAutocompleteService.search_conditions[:starts_with]
  )
    query = guardian_scoped.user.bookmarks

    if condition == HashtagAutocompleteService.search_conditions[:starts_with]
      query = query.where("name ILIKE ?", "#{term}%")
    else
      query = query.where("name ILIKE ?", "%#{term}%")
    end

    query
      .limit(limit)
      .map do |bm|
        HashtagAutocompleteService::HashtagItem.new.tap do |item|
          item.text = bm.name
          item.slug = bm.name.gsub(" ", "-")
          item.icon = icon
        end
      end
  end

  def self.search_sort(search_results, _)
    search_results.sort_by { |item| item.text.downcase }
  end
end
