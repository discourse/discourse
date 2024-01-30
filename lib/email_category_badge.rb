# frozen_string_literal: true

module EmailCategoryBadge
  def self.html_for(category, opts = nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    result = +""

    parent_category =
      Category.find_by(id: category.parent_category_id) unless category.parent_category_id.nil?

    category_url =
      opts[:absolute_url] ? "#{Discourse.base_url_no_prefix}#{category.url}" : category.url

    # category wrapper styles
    styles = { color: "##{category.text_color}" }
    style_value = styles.map { |k, v| "#{k}: #{ERB::Util.html_escape(v)};" }.join(" ")

    # current category badge styles
    badge_styles = {
      display: "inline-block",
      width: "0.72em",
      height: "0.72em",
      "margin-right": "0.33em",
    }
    badge_styles["background-color"] = "##{category.color}"
    badge_style_value = badge_styles.map { |k, v| "#{k}: #{ERB::Util.html_escape(v)};" }.join(" ")

    # parent category badge styles
    parent_badge_styles = { display: "block", width: "0.36em", height: "0.72em" }
    parent_badge_styles["background-color"] = "##{parent_category.color}" if parent_category
    parent_badge_style_value =
      parent_badge_styles.map { |k, v| "#{k}: #{ERB::Util.html_escape(v)};" }.join(" ")

    # category badge structure
    result << "<span data-category-id='#{category.id}'"
    result << " data-parent-category-id='#{parent_category.id}'" if parent_category
    result << " data-drop-close='true'>"
    result << "<span>"
    result << "<span style='#{badge_style_value}'>"
    result << "<span style='#{parent_badge_style_value}'></span>" if parent_category
    result << "</span>"
    result << ERB::Util.html_escape(category.name)
    result << "</span></span>"

    # wrapping link
    result =
      "<a class='badge-category__wrapper' style='#{style_value}' href='#{category_url}'>#{result}</a>"

    result.html_safe
  end
end