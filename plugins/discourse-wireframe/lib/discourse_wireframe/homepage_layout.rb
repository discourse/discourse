# frozen_string_literal: true

module DiscourseWireframe
  # Whether a theme has a homepage layout to show. A layout only counts while it
  # is part of the theme's stack, so a saved layout that isn't installed (a draft)
  # doesn't make the homepage custom for visitors.
  module HomepageLayout
    OUTLET = "homepage-blocks"

    def self.published?(theme_id)
      ThemeField
        .where(
          theme_id: Theme.transform_ids(theme_id),
          type_id: ThemeField.types[:block_layout],
          name: OUTLET,
          error: nil,
        )
        .where.not(value_baked: [nil, ""])
        .exists?
    end
  end
end
