module CategoryBadge

  def self.category_stripe(color, classes)
    style = color ? "style='background-color: ##{color};'" : ''
    "<span class='#{classes}' #{style}></span>"
  end

  def self.html_for(category, opts=nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    extra_classes = "#{opts[:extra_classes]} #{SiteSetting.category_style}"

    result = ''

    unless category.parent_category_id.nil? || opts[:hide_parent]
      parent_category = Category.find_by(id: category.parent_category_id)
      result << category_stripe(parent_category.color, 'badge-category-parent-bg')
    end
    result << category_stripe(category.color, 'badge-category-bg')

    class_names = 'badge-category clear-badge'
    text_color = "##{category.text_color}"
    description = category.description_text ? "title='#{category.description_text.html_safe}'" : ''

    result << "<span style='color: #{text_color};' data-drop-close='true' class='#{class_names}'
                 #{description}'>"

    result << category.name.html_safe << '</span>'
    "<a class='badge-wrapper #{extra_classes}' href='#{Discourse.base_url}#{category.url}'>#{result}</a>"
  end
end
