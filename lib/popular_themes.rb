# frozen_string_literal: true

# Themes and components maintained by Discourse that admins are offered when
# installing a theme. Descriptions are translated under `popular_themes`.
module PopularThemes
  LIST = [
    {
      id: "graceful",
      name: "Graceful",
      remote_url: "https://github.com/discourse/graceful",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/graceful-theme",
      screenshot_url:
        "https://github.com/discourse/graceful/blob/main/screenshots/light.png?raw=true",
      meta_url: "https://meta.discourse.org/t/graceful-theme/93040",
    },
    {
      id: "material_design",
      name: "Material Design Theme",
      remote_url: "https://github.com/discourse/material-design-stock-theme",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/material-design-theme",
      screenshot_url:
        "https://github.com/discourse/material-design-stock-theme/blob/main/screenshots/light.png?raw=true",
      meta_url: "https://meta.discourse.org/t/material-design-theme/47142",
    },
    {
      id: "mint",
      name: "Mint",
      remote_url: "https://github.com/discourse/discourse-mint-theme",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/mint-theme",
      screenshot_url:
        "https://github.com/discourse/discourse-mint-theme/blob/main/screenshots/light.webp?raw=true",
      meta_url: "https://meta.discourse.org/t/mint-theme/202822",
    },
    {
      id: "simple",
      name: "Sam's Simple Theme",
      remote_url: "https://github.com/discourse/discourse-simple-theme",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/sams-simple-theme",
      screenshot_url:
        "https://github.com/discourse/discourse-simple-theme/blob/main/screenshots/light.png?raw=true",
      meta_url: "https://meta.discourse.org/t/sams-simple-theme/23552",
    },
    {
      id: "concord",
      name: DesignWizard::Themes::CONCORD[:name],
      remote_url: DesignWizard::Themes::CONCORD[:remote_url],
      screenshot_url: DesignWizard::Themes::CONCORD[:screenshot_light_url],
      description_key: DesignWizard::Themes::CONCORD[:description_key],
    },
    {
      id: "brand_header",
      name: "Brand Header",
      remote_url: "https://github.com/discourse/discourse-brand-header",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/brand-header",
      meta_url: "https://meta.discourse.org/t/brand-header/77977",
      component: true,
    },
    {
      id: "custom_header_links",
      name: "Custom Header Links",
      remote_url: "https://github.com/discourse/discourse-custom-header-links",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/custom-header-links",
      meta_url: "https://meta.discourse.org/t/custom-header-links/90588",
      component: true,
    },
    {
      id: "category_banners",
      name: "Category Banners",
      remote_url: "https://github.com/discourse/discourse-category-banners",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/category-banners",
      meta_url: "https://meta.discourse.org/t/category-banners/86241",
      component: true,
    },
    {
      id: "tag_banners",
      name: "Tag Banners",
      remote_url: "https://github.com/discourse/discourse-tag-banners",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/tag-banners",
      meta_url: "https://meta.discourse.org/t/tag-banners/124240",
      component: true,
    },
    {
      id: "sidebar_theme_toggle",
      name: "Sidebar Theme Toggle",
      remote_url: "https://github.com/discourse/discourse-sidebar-theme-toggle",
      meta_url: "https://meta.discourse.org/t/sidebar-theme-toggle/242802",
      component: true,
    },
    {
      id: "header_submenus",
      name: "Header Submenus",
      remote_url: "https://github.com/discourse/discourse-header-submenus",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/header-submenus",
      meta_url: "https://meta.discourse.org/t/header-submenus/94584",
      component: true,
    },
    {
      id: "table_of_contents",
      name: "Automatic Table of Contents",
      remote_url: "https://github.com/discourse/DiscoTOC",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/discotoc",
      meta_url: "https://meta.discourse.org/t/discotoc-automatic-table-of-contents/111143",
      component: true,
    },
    {
      id: "easy_footer",
      name: "Easy Responsive Footer",
      remote_url: "https://github.com/discourse/Discourse-easy-footer",
      preview_url: "https://discourse.theme-creator.io/theme/Discourse/easy-responsive-footer",
      meta_url: "https://meta.discourse.org/t/easy-responsive-footer/95818",
      component: true,
    },
  ].freeze

  # Every entry, with its description in the current locale and local
  # screenshot paths made absolute for subfolder installs.
  def self.all
    LIST.map { |entry| present(entry) }
  end

  def self.themes
    all.reject { |entry| entry[:component] }
  end

  def self.find_by_remote_url(url)
    return if url.blank?

    url = normalize_url(url)
    entry = LIST.find { |candidate| normalize_url(candidate[:remote_url]) == url }
    present(entry) if entry
  end

  def self.description_for(url)
    find_by_remote_url(url)&.dig(:description)
  end

  def self.present(entry)
    screenshot_url = entry[:screenshot_url]
    screenshot_url = Discourse.base_path + screenshot_url if screenshot_url&.start_with?("/")
    {
      id: entry[:id],
      name: entry[:name],
      description: I18n.t(entry[:description_key] || "popular_themes.#{entry[:id]}.description"),
      remote_url: entry[:remote_url],
      preview_url: entry[:preview_url],
      screenshot_url:,
      meta_url: entry[:meta_url],
      component: entry[:component] == true,
    }.compact
  end
  private_class_method :present

  def self.normalize_url(url)
    url.to_s.strip.delete_suffix(".git").delete_suffix("/").downcase
  end
  private_class_method :normalize_url
end
