module PostItemExcerpt

  def self.included(base)
    base.attributes(:excerpt, :truncated)
  end

  def cooked
    @cooked ||= object.cooked || PrettyText.cook(object.raw)
  end

  def excerpt
    return nil unless cooked
    @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
  end

  def truncated
    true
  end

  def include_truncated?
    cooked.length > 300
  end

end
