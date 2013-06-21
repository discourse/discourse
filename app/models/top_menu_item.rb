# Public: Instances of TopMenuItem should be instantiated from segments contained in SiteSetting.top_menu.
# Exposes relevant properties and methods that dictate which query methods should be called from the ListController.
# Segment data should start with a route fragment in one of the following formats:
#   a topic route, such as 'latest' or 'new' (see ListController for valid options)
#   the literal string "categories"
#   a specific category route, must start with 'category/' followed by the route, i.e. 'category/xyz'
#
# A topic route can optionally specify a single category to exclude using the '-category' option, i.e. 'new,-xyz'
#
# Examples
#
#   item = TopMenuItem.new('unread')
#   item.name           # => "unread"
#
#   item = TopMenuItem.new('latest,-video')
#   item.name           # => "latest"
#   item.has_filter?    # => true
#   item.filter         # => "video"
#
#   item = TopMenuItem.new('category/hardware')
#   item.name                     # => "category"
#   item.has_filter?              # => false
#   item.has_specific_category?   # => true
#   item.specific_category        # => "hardware"
class TopMenuItem
  def initialize(value)
    parts = value.split(',')
    @name = parts[0]
    @filter = initialize_filter(parts[1])
  end

  attr_reader :name, :filter

  def has_filter?
    !filter.nil?
  end

  def has_specific_category?
    name.split('/')[0] == 'category'
  end

  def specific_category
    name.split('/')[1]
  end

  def query_should_exclude_category?(action_name, format)
    if format.blank? || format == "html"
      matches_action?(action_name) && has_filter?
    else
      false
    end
  end

  def matches_action?(action_name)
    return true if action_name == "index" && name == SiteSetting.homepage
    return true if name == action_name
    false
  end

  private

  def initialize_filter(value)
    if value
      if value.start_with?('-')
        value[1..-1] # all but the leading -
      else
        Rails.logger.warn "WARNING: found top_menu_item with invalid filter, ignoring '#{value}'..."
        nil
      end
    end
  end
end