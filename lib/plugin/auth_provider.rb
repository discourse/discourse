class Plugin::AuthProvider
  attr_accessor :glyph, :background_color, :title,
                :message, :frame_width, :frame_height, :authenticator

  def name
    authenticator.name
  end

end
