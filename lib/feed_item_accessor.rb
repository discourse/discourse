class FeedItemAccessor
  attr_accessor :rss_item

  def initialize(rss_item)
    @rss_item = rss_item
  end

  def element_content(element_name)
    try_attribute_or_self(element(element_name), :content)
  end

  def link
    try_attribute_or_self(element(:link), :href)
  end

  private

  def element(element_name)
    rss_item.respond_to?(element_name) ? rss_item.send(element_name) : nil
  end

  def try_attribute_or_self(element, attribute_name)
    element.respond_to?(attribute_name) ? element.send(attribute_name) : element
  end
end
