# frozen_string_literal: true

module ::Blog
  # The categories the plugin creates when the blog first needs them.
  module ManagedCategories
    MAX_NAME_ATTEMPTS = 10

    def self.drafts_permissions
      existing_group_ids(Roles.editorial_group_ids).index_with do
        CategoryGroup.permission_types[:full]
      end
    end

    def self.sync_role_access
      Instance.category_ids.each do |category_id|
        AddPublishersToPublicCategory.call(params: { category_id: })
      end
      EnsureDraftsCategory.call(options: { create_missing: false })
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
      candidates.find { |name| !category_name_taken?(name) } || "#{base} #{SecureRandom.hex(4)}"
    end

    def self.public_permissions
      { Group::AUTO_GROUPS[:everyone] => CategoryGroup.permission_types[:create_post] }.merge(
        publisher_group_ids.index_with { CategoryGroup.permission_types[:full] },
      )
    end

    def self.publisher_group_ids
      existing_group_ids(Roles.publisher_group_ids)
    end

    # The default blog's category predates blog names, so it keeps its own name.
    # Other blogs get "Engineering Blog", which rarely clashes with a category
    # the community already has.
    def self.public_category_name(blog)
      locale = SiteSetting.default_locale
      suffix = I18n.t("blog.categories.public", locale:)
      return suffix if blog.is_default?
      return blog.name if blog.name.downcase.end_with?(suffix.downcase)
      I18n.t("blog.categories.public_named", name: blog.name, locale:)
    end

    def self.public_category_description
      I18n.t("blog.categories.public_description", locale: SiteSetting.default_locale)
    end

    # An existing category with the default name is never adopted: it may belong
    # to something else, and adopting it would change who can post there.
    def self.public_category_name_taken?(blog)
      category_name_taken?(public_category_name(blog))
    end

    # A category the blog also uses for something else is never its drafts category.
    def self.drafts_category
      Category
        .where.not(id: [*Instance.category_ids, SiteSetting.shared_drafts_category.to_i])
        .find_by(id: stored_category_id(:blog_drafts_category))
    end

    def self.public_category(blog)
      Category.find_by(id: blog.category_id)
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

    def self.category_name_taken?(name)
      Category.where(parent_category_id: nil).where("LOWER(name) = LOWER(?)", name).exists?
    end
  end
end
