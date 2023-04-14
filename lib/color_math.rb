# frozen_string_literal: true

module ColorMath
  # Equivalent to dc-color-brightness() in variables.scss
  def self.brightness(color)
    rgb = Converters.hex_to_rgb(color)
    (rgb[0].to_i * 299 + rgb[1].to_i * 587 + rgb[2].to_i * 114) / 1000.0
  end

  # Equivalent to dark-light-diff() in variables.scss
  def self.dark_light_diff(adjusted_color, comparison_color, lightness, darkness)
    if brightness(adjusted_color) < brightness(comparison_color)
      scale_color_lightness(adjusted_color, lightness)
    else
      scale_color_lightness(adjusted_color, darkness)
    end
  end

  # Equivalent to scale_color(color, lightness: ) in sass
  def self.scale_color_lightness(color, adjustment)
    rgb = Converters.hex_to_rgb(color)
    h, s, l = Converters.rgb_to_hsl(*rgb)

    l =
      if adjustment > 0
        l + (100 - l) * adjustment
      else
        l + l * adjustment
      end

    rgb = Converters.hsl_to_rgb(h, s, l)
    Converters.rgb_to_hex(rgb)
  end

  module Converters
    # Adapted from https://github.com/anilyanduri/color_math
    #
    # The MIT License (MIT)
    #
    # Copyright (c) 2016 Anil Yanduri
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    #
    # The above copyright notice and this permission notice shall be included in all
    # copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    # SOFTWARE.

    def self.hex_to_rgb(color)
      color = color.gsub(/(.)/, '\1\1') if color.length == 3
      raise new RuntimeError("Hex color must be 6 characters") if color.length != 6
      color.scan(/../).map { |c| c.to_i(16) }
    end

    def self.rgb_to_hex(rgb)
      rgb.map { |c| c.to_s(16).rjust(2, "0") }.join("")
    end

    def self.rgb_to_hsl(r, g, b)
      r /= 255.0
      g /= 255.0
      b /= 255.0
      max = [r, g, b].max
      min = [r, g, b].min
      h = (max + min) / 2.0
      s = (max + min) / 2.0
      l = (max + min) / 2.0

      if (max == min)
        h = 0
        s = 0 # achromatic
      else
        d = max - min
        s = l >= 0.5 ? d / (2.0 - max - min) : d / (max + min)
        case max
        when r
          h = (g - b) / d + (g < b ? 6.0 : 0)
        when g
          h = (b - r) / d + 2.0
        when b
          h = (r - g) / d + 4.0
        end
        h /= 6.0
      end
      [(h * 360).round, (s * 100).round, (l * 100).round]
    end

    def self.hsl_to_rgb(h, s, l)
      h = h / 360.0
      s = s / 100.0
      l = l / 100.0

      r = 0.0
      g = 0.0
      b = 0.0

      if (s == 0.0)
        r = l.to_f
        g = l.to_f
        b = l.to_f #achromatic
      else
        q = l < 0.5 ? l * (1 + s) : l + s - l * s
        p = 2 * l - q
        r = hue_to_rgb(p, q, h + 1 / 3.0)
        g = hue_to_rgb(p, q, h)
        b = hue_to_rgb(p, q, h - 1 / 3.0)
      end

      [(r * 255).round, (g * 255).round, (b * 255).round]
    end

    def self.hue_to_rgb(p, q, t)
      t += 1 if (t < 0)
      t -= 1 if (t > 1)
      return(p + (q - p) * 6 * t) if (t < 1 / 6.0)
      return q if (t < 1 / 2.0)
      return(p + (q - p) * (2 / 3.0 - t) * 6) if (t < 2 / 3.0)
      p
    end
  end
end
