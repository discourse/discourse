# frozen_string_literal: true

require "unicode/display_width"

# A small line-based ANSI terminal model used to reconstruct what a real
# terminal would show after consuming the bytes a reporter wrote, so the
# reporter specs can assert on the visible screen without a real emulator. It
# models the two wrap behaviours a resize can produce (truncate and reflow) so
# the reflow invariants can be checked too.
#
# The reporter always rewrites whole lines (`\r`, content, erase), parks the
# cursor at column 0, and keeps every emitted line strictly narrower than the
# terminal — so at a constant width physical rows map 1:1 to logical lines and
# tracking lines + cursor row is enough. A resize is the only place physical
# wrapping matters; `#resize` applies the chosen `wrap_mode`.
class AnsiScreen
  SGR = /\e\[[0-9;]*m/

  attr_reader :width, :wrap_mode

  # wrap_mode: :truncate (xterm-like, a long row stays one physical row) or
  # :reflow (modern emulators / tmux, a long row rewraps into several rows).
  def initialize(width: 80, wrap_mode: :truncate)
    @width = width
    @wrap_mode = wrap_mode
    @lines = [+""]
    @row = 0
    @pending = +"" # visible text written since the last carriage return on this row
  end

  def feed(data)
    data.scan(/\e\[[0-9;?]*[A-Za-z]|\e[78]|\r\n|\r|\n|[^\e\r\n]+/m).each { |token| handle(token) }
    self
  end

  # Change the width the way the chosen terminal type would, then use the new
  # width for later writes.
  def resize(new_width)
    reflow(new_width) if @wrap_mode == :reflow
    @width = new_width
    self
  end

  # Visible rows, SGR-stripped and right-trimmed. In :reflow mode rows wider
  # than the width are split into the physical rows the emulator would show.
  def rows
    visible = @lines.map { |line| strip(line) }
    visible = visible.flat_map { |line| wrap_row(line) } if @wrap_mode == :reflow
    visible.map(&:rstrip)
  end

  def to_s
    rows.join("\n")
  end

  # Non-empty rows only — handy for asserting "this text is present, in order".
  def content_rows
    rows.reject(&:empty?)
  end

  def self.display_width(string)
    Unicode::DisplayWidth.of(string.gsub(SGR, ""))
  end

  private

  def handle(token)
    case token
    when /\A\e\[(\d*)A\z/
      move_up(Regexp.last_match(1).empty? ? 1 : Regexp.last_match(1).to_i)
    when /\A\e\[(\d*)B\z/
      move_down(Regexp.last_match(1).empty? ? 1 : Regexp.last_match(1).to_i)
    when /\A\e\[2K\z/
      @lines[@row] = +""
      @pending = +""
    when /\A\e\[0?K\z/
      @lines[@row] = @pending.dup
    when /\A\e\[0?J\z/
      @lines[@row] = @pending.dup
      (@row + 1...@lines.size).each { |i| @lines[i] = +"" }
    when /\A\e\[\?25[lh]\z/, SGR, "\e7", "\e8"
      nil # cursor visibility / SGR / save-restore: irrelevant to the visible text
    when "\r\n"
      move_down(1)
      reset_pending
    when "\r"
      reset_pending
    when "\n"
      move_down(1)
    when /\A\e/
      nil # any other escape: ignore
    else
      # The reporter writes a whole line after `\r`, so text replaces from the
      # start of the line.
      @pending << token
      @lines[@row] = @pending.dup
    end
  end

  def move_up(count)
    @row = [@row - count, 0].max
    @pending = @lines[@row].dup
  end

  def move_down(count)
    @row += count
    (@lines.size..@row).each { |i| @lines[i] = +"" }
    @pending = @lines[@row].dup
  end

  def reset_pending
    @pending = +""
  end

  def strip(line)
    line.gsub(SGR, "")
  end

  # Split one stored logical line into the physical rows a reflowing terminal
  # would wrap it into at the current width.
  def wrap_row(line)
    return [line] if AnsiScreen.display_width(line) <= @width

    pieces = []
    current = +""
    width = 0
    line.each_grapheme_cluster do |cluster|
      w = Unicode::DisplayWidth.of(cluster)
      if width + w > @width
        pieces << current
        current = +""
        width = 0
      end
      current << cluster
      width += w
    end
    pieces << current unless current.empty?
    pieces
  end

  # On a reflow resize, split every stored line again at the new width. We don't
  # track where the cursor ends up after a reflow (real terminals don't agree on
  # it); the reporter copes with that, and the tests only check that the history
  # survives and nothing is garbled.
  def reflow(new_width)
    old_width = @width
    @width = new_width
    @lines = @lines.flat_map { |line| wrap_row(strip(line)) }
    @width = old_width
    @row = [@row, @lines.size - 1].min
    @pending = @lines[@row].dup
  end
end
