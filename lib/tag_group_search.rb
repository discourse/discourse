# frozen_string_literal: true

class TagGroupSearch
  def self.search(guardian, q: nil, names: nil, limit: SiteSetting.max_tag_search_results)
    matches = TagGroup.visible(guardian).includes(:base_tags)

    matches = matches.where("lower(name) ILIKE ?", "%#{q.strip}%") if q.present?

    matches = matches.where("lower(NAME) in (?)", names.map(&:downcase)) if names.present?

    matches = matches.order("name").limit(limit).to_a
    visible_tag_ids = DiscourseTagging.visible_tag_ids(matches.flat_map(&:base_tags), guardian)

    results =
      matches.map do |tag_group|
        tags = tag_group.base_tags.select { |tag| visible_tag_ids.include?(tag.id) }

        {
          name: tag_group.name,
          tags: tags.map { |tag| { id: tag.id, name: tag.name, slug: tag.slug } },
        }
      end

    results
  end
end
