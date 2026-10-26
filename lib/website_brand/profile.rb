# frozen_string_literal: true

module WebsiteBrand
  # The colors and fonts a website uses for its brand, reduced to values that
  # are safe to pass on: six-digit hex colors, keys from Discourse's own font
  # list, and the page's URL. Nothing else from the page is kept.
  #
  # `confidence` is :high, :medium or :low, depending on how strongly the page
  # points at its brand color. `candidates` lists the likeliest brand colors,
  # strongest first. `body_font` and `heading_font` are WebsiteBrand::Fonts::Match
  # objects, or nil.
  Profile =
    Data.define(
      :url,
      :confidence,
      :brand,
      :accent,
      :header,
      :background,
      :dark,
      :candidates,
      :body_font,
      :heading_font,
    )
end
