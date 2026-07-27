# frozen_string_literal: true

require "unicode/display_width"

module Migrations
  module Reporting
    class Tui
      # ANSI and text-width helpers. `unicode-display_width` only looks values up
      # in a table. It never asks the terminal anything (unlike Reline's `\e[6n`),
      # so it can't hang.
      module Ansi
        RESET = "\e[0m"
        BOLD = "\e[1m"
        GREEN = "\e[32m"
        YELLOW = "\e[33m"
        RED = "\e[31m"
        CYAN = "\e[36m"
        MAGENTA = "\e[35m"
        DIM = "\e[90m"
        ERASE_LINE = "\e[2K" # erase the whole line (also clears the terminal's wrap flag)
        ERASE_BELOW = "\e[0J" # erase from the cursor to the end of the screen
        HIDE_CURSOR = "\e[?25l"
        SHOW_CURSOR = "\e[?25h"

        # Matches SGR ("Select Graphic Rendition") sequences — the color and
        # style codes above, e.g. "\e[1m". They have no visible width, so the
        # width and truncate helpers below strip or skip them.
        SGR = /\e\[[0-9;]*m/

        def self.cursor_up(count)
          "\e[#{count}A"
        end

        # The display width, ignoring SGR color codes. It only removes them
        # (which makes a copy) when the string really has an escape; most cells
        # are plain text.
        def self.width(string)
          string = string.gsub(SGR, "") if string.include?("\e")
          Unicode::DisplayWidth.of(string)
        end

        # Cut the line down to a visible width, keeping the SGR color codes whole.
        def self.truncate(line, max)
          return line if width(line) <= max

          out = +""
          used = 0
          emitted_sgr = false
          line.scan(/#{SGR}|\X/) do |token|
            if token.start_with?("\e")
              out << token
              emitted_sgr = true
              next
            end
            w = Unicode::DisplayWidth.of(token)
            break if used + w > max
            out << token
            used += w
          end
          out << RESET if emitted_sgr
          out
        end

        # Pad to a display width (wide characters count as 2; SGR codes ignored).
        def self.pad(string, target, align = :left)
          pad_to(string, width(string), target, align)
        end

        # Like `Ansi.pad` above, but the caller already knows the string's display
        # width. This way each cell is measured once, and the width is reused for
        # both the column sizing and the padding.
        def self.pad_to(string, string_width, target, align = :left)
          gap = target - string_width
          return string if gap <= 0
          align == :right ? "#{" " * gap}#{string}" : "#{string}#{" " * gap}"
        end
      end
    end
  end
end
