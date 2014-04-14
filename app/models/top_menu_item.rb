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
    filter.present?
  end

  def has_specific_category?
    name.split('/')[0] == 'category'
  end

  def specific_category
    name.split('/')[1]
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
