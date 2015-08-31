module ImageSizer

  # Resize an image to the aspect ratio we want
  def self.resize(width, height, opts = {})
    return if width.blank? || height.blank?

    max_width = (opts[:max_width] || SiteSetting.max_image_width).to_f
    max_height = (opts[:max_height] || SiteSetting.max_image_height).to_f

    w = width.to_f
    h = height.to_f

    return [w.floor, h.floor] if w <= max_width && h <= max_height

    ratio = [max_width / w, max_height / h].min
    [(w * ratio).floor, (h * ratio).floor]
  end

end
