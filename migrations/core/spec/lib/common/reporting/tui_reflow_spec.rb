# frozen_string_literal: true

require "stringio"

# Reflow is the one case a plain PTY test can't judge (a PTY only delivers
# WINCH; rewrapping is emulator display behaviour). The screen interpreter
# models both wrap families and asserts the recovery invariants under each.
RSpec.describe Migrations::Reporting::Tui do
  describe "the reflow recovery invariants (interpreter)" do
    # A StringIO that also answers `tty?`/`winsize`, so the renderer's real
    # resize path runs (consume_resize re-reads winsize at a frame boundary).
    def fake_tty(cols)
      io = StringIO.new
      io.define_singleton_method(:winsize) { @winsize ||= [40, cols] }
      io.define_singleton_method(:winsize=) { |value| @winsize = value }
      io.define_singleton_method(:tty?) { true }
      io
    end

    %i[truncate reflow].each do |wrap_mode|
      it "keeps history and the live region uncorrupted on shrink (#{wrap_mode})" do
        time = [0.0]
        io = fake_tty(60)
        renderer = Migrations::Reporting::Tui::Renderer.new(output: io, clock: -> { time[0] })

        renderer.apply([:start, "Categories", "Categories"])
        renderer.apply([:progress_begin, "Categories", 10])
        renderer.apply([:finish, "Categories", :done]) # a permanent history line
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        time[0] = 2.0
        renderer.apply([:progress, "Posts", 400, 0, 0, 0])
        renderer.repaint

        mark = io.string.length
        screen = AnsiScreen.new(width: 60, wrap_mode:).feed(io.string)

        # Shrink: the emulator rewraps (reflow) or not (truncate); the renderer
        # consumes the resize at the next frame and repaints at the new width.
        io.winsize = [40, 30]
        screen.resize(30)
        renderer.mark_resize
        time[0] = 3.0
        renderer.apply([:progress, "Posts", 600, 0, 0, 0])
        renderer.consume_resize # the render loop does this between drain and repaint
        renderer.repaint
        screen.feed(io.string[mark..])

        rows = screen.content_rows

        # History survives (possibly duplicated under reflow — that's allowed).
        expect(rows).to include(a_string_starting_with("✓ Categories"))
        # The live region is intact: the running row is present with its percent.
        expect(rows).to include(a_string_matching(/Posts.*%/))
        # Nothing is garbled: no row merges two logical lines (the bug the
        # erase-entire-line + bounded-reclaim fixes — a finished ✓ line fused
        # with a live percent, or two titles on one row).
        expect(rows).to(be_none { |row| row.include?("✓") && row.include?("%") })
        expect(rows).to(be_none { |row| row.include?("Categories") && row.include?("Posts") })
      end
    end
  end
end
