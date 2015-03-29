module CategoryBadge

  def self.html_for(category, opts=nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    category_url = "#{Discourse.base_url}#{category.url}"

    result = ""

    result << "<a href='#{category_url}' style='background-color: ##{category.color}; font-size: 12px; padding: 2px 1px; font-weight: bold; margin: 0; width: 2px; white-space:nowrap;'>&nbsp;</a>"

    unless category.parent_category_id.nil?
      parent_category = Category.find_by(id: category.parent_category_id)
      result << "<a href='#{category_url}' style='background-color: ##{parent_category.color}; font-size: 12px; padding: 2px 1px; font-weight: bold; margin: 0; width: 2px; white-space:nowrap;'>&nbsp;</a>"
    end

    result << "<a href='#{category_url}' style='font-size: 12px; font-weight: bold; margin-left: 3px; color: #222;'>#{category.name}</a>"

    "<span class='badge-wrapper'>#{result}</span>"
  end

end
