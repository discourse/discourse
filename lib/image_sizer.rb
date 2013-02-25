module ImageSizer

  # Resize an image to the aspect ratio we want
  def self.resize(width, height)
    max_width = SiteSetting.max_image_width.to_f
    return nil if width.blank? or height.blank?

    w = width.to_f
    h = height.to_f

    return [w.floor, h.floor] if w < max_width

    # Using the maximum width, resize the heigh retaining the aspect ratio
    [max_width.floor, (h * (max_width / w)).floor]
  end

end
