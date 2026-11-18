# frozen_string_literal: true

module ::Blog
  # The categories the plugin creates when the blog first needs them.
  module ManagedCategories
    MAX_NAME_ATTEMPTS = 10

    def self.editorial_group_ids
      (
        SiteSetting.blog_contributor_groups_map + SiteSetting.blog_editor_groups_map +
          SiteSetting.blog_publisher_groups_map
      ).uniq
    end

    def self.drafts_permissions
      editorial_group_ids.index_with { CategoryGroup.permission_types[:full] }
    end

    def self.drafts_permissions_current?(category)
      return false if !category.read_restricted?
      category.category_groups.pluck(:group_id, :permission_type).to_h == drafts_permissions
    end

    # The drafts category is never chosen by hand, so it takes the first free name
    # rather than failing on a clash with an unrelated category.
    def self.drafts_category_name
      base = I18n.t("blog.categories.drafts", locale: SiteSetting.default_locale)
      candidates = [base] + (2..MAX_NAME_ATTEMPTS).map { |n| "#{base} #{n}" }
      candidates.find { |name| !top_level_name_taken?(name) } || "#{base} #{SecureRandom.hex(4)}"
    end

    def self.public_permissions
      { Group::AUTO_GROUPS[:everyone] => CategoryGroup.permission_types[:create_post] }.merge(
        SiteSetting.blog_publisher_groups_map.index_with { CategoryGroup.permission_types[:full] },
      )
    end

    def self.public_category_name
      I18n.t("blog.categories.public", locale: SiteSetting.default_locale)
    end

    # An existing category with the default name is never adopted: it may belong
    # to something else, and adopting it would change who can post there.
    def self.public_category_name_taken?
      top_level_name_taken?(public_category_name)
    end

    def self.public_category
      Category.find_by(id: SiteSetting.blog_category)
    end

    # Core blanks a clashing auto-generated slug, which leaves an id-only URL.
    def self.available_slug(name)
      base = Slug.for(name, "")
      return if base.blank?
      candidates = [base] + (2..MAX_NAME_ATTEMPTS).map { |n| "#{base}-#{n}" }
      candidates.find { |slug| !Category.exists?(parent_category_id: nil, slug:) }
    end

    def self.top_level_name_taken?(name)
      Category.where(parent_category_id: nil).where("LOWER(name) = LOWER(?)", name).exists?
    end
    private_class_method :top_level_name_taken?
  end
end
