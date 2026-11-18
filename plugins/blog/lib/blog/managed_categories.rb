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
      existing_group_ids(editorial_group_ids).index_with { CategoryGroup.permission_types[:full] }
    end

    def self.drafts_permissions_current?(category)
      return false if !category.read_restricted?
      category.category_groups.pluck(:group_id, :permission_type).to_h == drafts_permissions
    end

    # The drafts category is never chosen by hand, so it takes the first free name
    # rather than failing on a clash with an unrelated category.
    def self.drafts_category_description
      I18n.t("blog.categories.drafts_description", locale: SiteSetting.default_locale)
    end

    def self.drafts_category_name
      base = I18n.t("blog.categories.drafts", locale: SiteSetting.default_locale)
      candidates = [base] + (2..MAX_NAME_ATTEMPTS).map { |n| "#{base} #{n}" }
      candidates.find { |name| !top_level_name_taken?(name) } || "#{base} #{SecureRandom.hex(4)}"
    end

    def self.public_permissions
      { Group::AUTO_GROUPS[:everyone] => CategoryGroup.permission_types[:create_post] }.merge(
        publisher_group_ids.index_with { CategoryGroup.permission_types[:full] },
      )
    end

    def self.publisher_group_ids
      existing_group_ids(SiteSetting.blog_publisher_groups_map)
    end

    def self.public_category_name
      I18n.t("blog.categories.public", locale: SiteSetting.default_locale)
    end

    def self.public_category_description
      I18n.t("blog.categories.public_description", locale: SiteSetting.default_locale)
    end

    # An existing category with the default name is never adopted: it may belong
    # to something else, and adopting it would change who can post there.
    def self.public_category_name_taken?
      top_level_name_taken?(public_category_name)
    end

    # A category the blog also uses for something else is never its drafts category.
    def self.drafts_category
      Category
        .where.not(id: [SiteSetting.blog_category.to_i, SiteSetting.shared_drafts_category.to_i])
        .find_by(id: stored_category_id(:blog_drafts_category))
    end

    def self.public_category
      Category.find_by(id: SiteSetting.blog_category)
    end

    # Read from the store rather than this process's copy of the settings, which can
    # lag behind a category another process has just created.
    def self.stored_category_id(setting)
      SiteSetting.provider.find(setting.to_sym)&.value
    end

    # Core blanks a clashing auto-generated slug, which leaves an id-only URL.
    def self.available_slug(name)
      base = Slug.for(name, "")
      return if base.blank?
      candidates = [base] + (2..MAX_NAME_ATTEMPTS).map { |n| "#{base}-#{n}" }
      candidates.find { |slug| !Category.exists?(parent_category_id: nil, slug:) }
    end

    # A deleted group can stay listed in a role setting.
    def self.existing_group_ids(ids)
      Group.where(id: ids).pluck(:id)
    end
    private_class_method :existing_group_ids

    def self.top_level_name_taken?(name)
      Category.where(parent_category_id: nil).where("LOWER(name) = LOWER(?)", name).exists?
    end
    private_class_method :top_level_name_taken?
  end
end
