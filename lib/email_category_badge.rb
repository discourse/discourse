module EmailCategoryBadge

  def self.inline_category_stripe(color, styles = '', spaces = 0)
    space = '&nbsp;'
    # Adds spaces for the Outlook email client for building the :bullet and :bar category stripes.
    "<span style='background-color: ##{color};#{styles}'><!--[if gte mso 9]>#{space * spaces}<![endif]--></span>"
  end

  def self.html_for(category, opts = nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    font_size = opts[:font_size] || "12px"

    # The line height here is giving the category badge some space.
    # This should possibly be given different values for different badge styles.
    badge_wrapper_styles = "font-size: #{font_size}; white-space: nowrap; line-height: 1.6;"

    has_parent = !!category.parent_category_id

    background_color = "##{category.color}"

    description = category.description_text ? "title='#{category.description_text.html_safe}'" : ''

    category_url = "#{Discourse.base_url}#{category.url}"

    # Styles for the category-name span.
    # parent_category.color could be used for the left border. It will have a mitered corner though.
    category_name_styles =
        case (SiteSetting.category_style || :box).to_sym
          when :bar then
            # left padding for outlook.com web client.
            'color: #222222; padding-left: 2px;'
          when :box then
            "color: ##{category.text_color}; background-color:#{background_color}; border-top: 2px solid #{background_color};" +
                "border-bottom: 2px solid #{background_color}; border-left: 4px solid #{background_color};" +
                "border-right: 4px solid #{background_color};"
          when :bullet then
            # left padding for outlook.com web client.
            'color: #222222; padding-left: 2px;'
        end

    result = ''

    # Create the category stripe for :bar and :box.
    # parent span
    if has_parent && !opts[:hide_parent]
      parent_category = Category.find_by(id: category.parent_category_id)
      result <<
          case (SiteSetting.category_style || :box).to_sym
            when :bar then
              inline_category_stripe(parent_category.color,
                                     'display: inline-block; vertical-align: middle; width: 2px; height: 12px;', 1)
            # There is no category stripe for :box. It uses background color and borders instead.
            when :box then
              ''
            when :bullet then
              inline_category_stripe(parent_category.color,
                                     'display: inline-block; width: 5px; height: 10px;', 1)
          end
    end

    # sub parent or main category span
    result <<
        case (SiteSetting.category_style || :box).to_sym
          when :bar then
            inline_category_stripe(category.color,
                                   "display: inline-block; vertical-align: middle; width: #{has_parent ? 2 : 4}px; height: 12px;", has_parent ? 1 : 2)
          when :box then
            ''
          when :bullet then
            inline_category_stripe(category.color,
                                   "display: inline-block; width: #{has_parent ? 5 : 10}px; height: 10px;", has_parent ? 1 : 2)
        end

    result << "<span style='#{category_name_styles}' #{description}>"

    # The initial " " is to give a space between the category bullet and name. Margins or
    # padding won't work on Outlook.
    result << " " + category.name.html_safe << '</span>'
    "<a class='badge-wrapper' href='#{category_url}' style='#{badge_wrapper_styles}'>#{result}</a>"
  end
end
