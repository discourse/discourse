# frozen_string_literal: true

# this class is used to track changes to an arbitrary buffer

class ContentBuffer

  def initialize(initial_content)
    @initial_content = initial_content
    @lines = @initial_content.split("\n")
  end

  def apply_transform!(transform)
    start_row = transform[:start][:row]
    start_col = transform[:start][:col]
    finish_row = transform[:finish][:row] if transform[:finish]
    finish_col = transform[:finish][:col] if transform[:finish]
    text = transform[:text]

    if transform[:operation] == :delete

      # fix first line

      l = @lines[start_row]
      l = l[0...start_col]

      if (finish_row == start_row)
        l << @lines[start_row][finish_col..-1]
        @lines[start_row] = l
        return
      end

      @lines[start_row] = l

      # remove middle lines
      (finish_row - start_row).times do
        l = @lines.delete_at start_row + 1
      end

      # fix last line
      @lines[start_row] << @lines[finish_row][finish_col - 1..-1]
    end

    if transform[:operation] == :insert

      @lines[start_row].insert(start_col, text)

      split = @lines[start_row].split("\n")

      if split.length > 1
        @lines[start_row] = split[0]
        i = 1
        split[1..-2].each do |line|
          @lines.insert(start_row + i, line)
          i += 1
        end
        @lines.insert(i, "") unless @lines.length > i
        @lines[i] = split[-1] + @lines[i]
      end

    end
  end

  def to_s
    @lines.join("\n")
  end
end
