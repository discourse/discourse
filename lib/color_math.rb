# frozen_string_literal: true

module ColorMath
  SRGB_LINEAR_LUMINANCE =
    Array
      .new(256) do |channel|
        value = channel / 255.0
        value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
      .freeze
  private_constant :SRGB_LINEAR_LUMINANCE

  # Equivalent to dc-color-brightness() in variables.scss
  def self.brightness(color)
    r, g, b = Converters.hex_to_rgb(color)
    (r * 299 + g * 587 + b * 114) / 1000.0
  end

  # Equivalent to dark-light-diff() in variables.scss
  def self.dark_light_diff(adjusted_color, comparison_color, lightness, darkness)
    r1, g1, b1 = Converters.hex_to_rgb(adjusted_color)
    r2, g2, b2 = Converters.hex_to_rgb(comparison_color)
    adjustment =
      (r1 * 299 + g1 * 587 + b1 * 114) < (r2 * 299 + g2 * 587 + b2 * 114) ? lightness : darkness

    h, s, l = Converters.rgb_to_hsl(r1, g1, b1)
    l = adjustment > 0 ? l + (100 - l) * adjustment : l + l * adjustment
    Converters.rgb_to_hex(Converters.hsl_to_rgb(h, s, l))
  end

  # WCAG 2 relative luminance, from 0 for black to 1 for white
  def self.relative_luminance(color)
    r, g, b = Converters.hex_to_rgb(color)
    (0.2126 * SRGB_LINEAR_LUMINANCE[r]) + (0.7152 * SRGB_LINEAR_LUMINANCE[g]) +
      (0.0722 * SRGB_LINEAR_LUMINANCE[b])
  end

  # WCAG 2 contrast ratio between two colors, from 1 to 21
  def self.contrast_ratio(color, other_color)
    lum1 = relative_luminance(color)
    lum2 = relative_luminance(other_color)
    lum1 < lum2 ? (lum2 + 0.05) / (lum1 + 0.05) : (lum1 + 0.05) / (lum2 + 0.05)
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

    HEX_NIBBLE =
      begin
        table = Array.new(256, -1)
        (0..9).each { |d| table[48 + d] = d }
        (0..5).each do |d|
          table[65 + d] = 10 + d
          table[97 + d] = 10 + d
        end
        table.freeze
      end

    BYTE_HEX = Array.new(256) { |i| i.to_s(16).rjust(2, "0").freeze }.freeze

    private_constant :HEX_NIBBLE, :BYTE_HEX

    def self.hex_to_rgb(color)
      if color.ascii_only?
        case color.bytesize
        when 6
          n0 = HEX_NIBBLE[color.getbyte(0)]
          n1 = HEX_NIBBLE[color.getbyte(1)]
          n2 = HEX_NIBBLE[color.getbyte(2)]
          n3 = HEX_NIBBLE[color.getbyte(3)]
          n4 = HEX_NIBBLE[color.getbyte(4)]
          n5 = HEX_NIBBLE[color.getbyte(5)]
          if (n0 | n1 | n2 | n3 | n4 | n5) >= 0
            return (n0 << 4) | n1, (n2 << 4) | n3, (n4 << 4) | n5
          end
        when 3
          n0 = HEX_NIBBLE[color.getbyte(0)]
          n1 = HEX_NIBBLE[color.getbyte(1)]
          n2 = HEX_NIBBLE[color.getbyte(2)]
          return (n0 << 4) | n0, (n1 << 4) | n1, (n2 << 4) | n2 if (n0 | n1 | n2) >= 0
        end
      end

      color = color.gsub(/(.)/, '\1\1') if color.length == 3
      raise "Hex color must be 6 characters" if color.length != 6
      color.scan(/../).map { |c| c.to_i(16) }
    end

    def self.rgb_to_hex(rgb)
      h0 = BYTE_HEX[rgb[0]]
      h1 = BYTE_HEX[rgb[1]]
      h2 = BYTE_HEX[rgb[2]]
      return "#{h0}#{h1}#{h2}" if h0 && h1 && h2

      rgb.map { |c| c.to_s(16).rjust(2, "0") }.join("")
    end

    def self.rgb_to_hsl(r, g, b)
      r /= 255.0
      g /= 255.0
      b /= 255.0
      max = r > g ? (r > b ? r : b) : (g > b ? g : b)
      min = r < g ? (r < b ? r : b) : (g < b ? g : b)
      l = (max + min) / 2.0

      if max == min
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

      if s == 0.0
        r = l.to_f
        g = l.to_f
        b = l.to_f # achromatic
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
      t += 1 if t < 0
      t -= 1 if t > 1
      return p + (q - p) * 6 * t if t < 1 / 6.0
      return q if t < 1 / 2.0
      return p + (q - p) * (2 / 3.0 - t) * 6 if t < 2 / 3.0
      p
    end
  end
end
