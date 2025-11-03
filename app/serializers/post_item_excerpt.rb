# frozen_string_literal: true

module PostItemExcerpt
  def self.included(base)
    base.attributes(:excerpt, :truncated)
  end

  def cooked
    @cooked ||= object.cooked || PrettyText.cook(object.raw)
  end

  def excerpt
    return nil unless cooked

    @excerpt ||=
      begin
        PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
      rescue ArgumentError => e
        e.message.include?("Document tree depth limit exceeded") ? "" : raise
      end
  end

  def truncated
    true
  end

  def include_truncated?
    cooked.length > 300
  end
end
