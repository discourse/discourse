# frozen_string_literal: true

module PostItemExcerpt
  def self.included(base)
    base.attributes(:excerpt, :truncated)
  end

  def cooked
    @cooked ||= object.cooked || PrettyText.cook(object.raw)
  end

  def excerpt
    return nil unless can_see_post_item_excerpt?
    return nil unless cooked
    @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
  end

  def include_excerpt?
    can_see_post_item_excerpt?
  end

  def include_cooked?
    can_see_post_item_excerpt?
  end

  def truncated
    true
  end

  def include_truncated?
    can_see_post_item_excerpt? && cooked.length > 300
  end

  private

  def can_see_post_item_excerpt?
    return true if !respond_to?(:post_item_excerpt_post) || post_item_excerpt_post.blank?
    scope&.can_see_post?(post_item_excerpt_post)
  end
end
