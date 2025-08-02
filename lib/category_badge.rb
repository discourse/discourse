# frozen_string_literal: true

module CategoryBadge
  def self.html_for(category, opts = nil)
    opts ||= {}

    # Bail if there is no category, hide uncategorized by default
    return "" if category.blank? || (category.uncategorized? && !opts[:show_uncategorized])

    if opts[:inline_style]
      # Inline styles for email
      style_for_email(category, opts)
    else
      # Browser styles
      style_for_browser(category, opts)
    end
  end

  def self.shared_data(category, opts)
    {
      parent_category: fetch_parent_category(category),
      category_url:
        opts[:absolute_url] ? "#{Discourse.base_url_no_prefix}#{category.url}" : category.url,
      extra_classes: opts[:extra_classes].to_s,
    }
  end

  def self.fetch_parent_category(category)
    Category.find_by(id: category.parent_category_id) if category.parent_category_id
  end

  def self.map_styles_to_string(styles)
    styles.map { |k, v| "#{k}: #{ERB::Util.html_escape(v)};" }.join(" ")
  end

  def self.wrap_in_link(content, url, extra_classes = "", style_value = nil)
    style_attr = style_value ? " style='#{style_value}'" : ""
    "<a class='badge-category__wrapper #{extra_classes}' href='#{url}'#{style_attr}>#{content}</a>".html_safe
  end

  def self.style_for_browser(category, opts)
    data = shared_data(category, opts)

    class_names = "badge-category #{data[:parent_category] ? "--has-parent" : ""}"
    description = category.description_text ? "title='#{category.description_text}'" : ""

    badge_styles = {
      "--category-badge-color": "##{category.color}",
      "--category-badge-text-color": "##{category.text_color}",
    }
    badge_styles["--parent-category-badge-color"] = "##{data[:parent_category].color}" if data[
      :parent_category
    ]

    result = +""
    result << "<span data-category-id='#{category.id}'"
    result << " style='#{map_styles_to_string(badge_styles)}'"
    result << " data-parent-category-id='#{data[:parent_category].id}'" if data[:parent_category]
    result << " data-drop-close='true' class='#{class_names}' #{description}>"
    result << "<span class='badge-category__name'>"
    result << ERB::Util.html_escape(category.name)
    result << "</span></span>"

    wrap_in_link(result, data[:category_url], data[:extra_classes])
  end

  def self.style_for_email(category, opts)
    data = shared_data(category, opts)

    badge_styles = {
      display: "inline-block",
      width: "0.72em",
      height: "0.72em",
      "margin-right": "0.33em",
      "background-color": "##{category.color}",
    }

    result = +""
    result << "<span data-category-id='#{category.id}'"
    result << " data-parent-category-id='#{data[:parent_category].id}'" if data[:parent_category]
    result << " data-drop-close='true'>"
    result << "<span>"
    result << "<span style='#{map_styles_to_string(badge_styles)}'>"
    if data[:parent_category]
      parent_badge_styles = { display: "block", width: "0.36em", height: "0.72em" }
      parent_badge_styles["background-color"] = "##{data[:parent_category].color}"
      parent_badge_style_value = map_styles_to_string(parent_badge_styles)
      result << "<span style='#{parent_badge_style_value}'></span>"
    end
    result << "</span>"
    result << ERB::Util.html_escape(category.name)
    result << "</span></span>"

    wrap_in_link(result, data[:category_url])
  end
end
