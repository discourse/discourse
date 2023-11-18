# frozen_string_literal: true

module CategoryBadge
  def self.html_for(category, opts = nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    extra_classes = "#{opts[:extra_classes]}"

    result = +""

    # parent class
    parent_category =
      Category.find_by(id: category.parent_category_id) unless category.parent_category_id.nil?
    has_parent_class = parent_category ? "--has-parent" : ""

    # category name
    class_names = "badge-category #{has_parent_class}"
    description = category.description_text ? "title='#{category.description_text}'" : ""
    category_url =
      opts[:absolute_url] ? "#{Discourse.base_url_no_prefix}#{category.url}" : category.url

    # category badge structure
    result << "<span data-category-id='#{category.id}'"
    result << " data-parent-category-id='#{parent_category.id}'" if parent_category
    result << " data-drop-close='true' class='#{class_names}' #{description}>"
    result << "<span class='badge-category__name'>"
    result << ERB::Util.html_escape(category.name)
    result << "</span></span>"

    # wrapping link
    result =
      "<a class='badge-category__wrapper #{extra_classes}' href='#{category_url}'>#{result}</a>"

    result.html_safe
  end
end
