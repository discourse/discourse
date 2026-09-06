# frozen_string_literal: true

module DiscourseRssPolling
  module RequiredTagGroups
    def self.for_category(category)
      return [] if category.nil?

      category
        .category_required_tag_groups
        .includes(tag_group: :tags)
        .map do |required|
          {
            tag_group: required.tag_group.name,
            min_count: required.min_count,
            tags: required.tag_group.tags.map(&:name),
          }
        end
    end
  end
end
