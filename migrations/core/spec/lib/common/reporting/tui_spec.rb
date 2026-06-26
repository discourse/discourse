# frozen_string_literal: true

require "stringio"

RSpec.describe Migrations::Reporting::Tui do
  # The bulk of the coverage drives the pure, single-threaded renderer directly
  # (injected clock, output, and width) and reconstructs the visible screen with
  # AnsiScreen — no threads, fully deterministic.
  describe Migrations::Reporting::Tui::Renderer do
    subject(:renderer) { described_class.new(output: io, width: 120, clock: -> { time[0] }) }

    let(:io) { StringIO.new }
    let(:time) { [0.0] } # mutable "now", advanced per step

    def at(seconds)
      time[0] = seconds
    end

    def screen(width: 200)
      AnsiScreen.new(width:).feed(io.string)
    end

    describe "a single determinate step" do
      before do
        renderer.apply([:start, "Categories", "Categories"])
        renderer.apply([:progress_begin, "Categories", 4281])
        at(0.5)
        renderer.apply([:progress, "Categories", 2000, 0, 0, 0])
        at(6.0)
        renderer.repaint
      end

      it "renders the percent, total count, elapsed, and rate" do
        row = screen.content_rows.first
        expect(row).to include("Categories")
        expect(row).to include("47%") # 2000 / 4281
        expect(row).to include("4,281") # the total, not the running current
        expect(row).not_to include("2,000") # current is conveyed by the percent
        expect(row).to include("0:06") # elapsed
        expect(row).to include("/s") # rate
      end

      it "renders a smoothed ETA once there is elapsed time and a rate" do
        expect(screen.content_rows.first).to match(/ETA \d+:\d{2}/)
      end

      it "shows <1/s rather than 0/s for a trickling step" do
        renderer.apply([:start, "Slow", "Slow"])
        renderer.apply([:progress_begin, "Slow", 1000])
        at(30.0)
        renderer.apply([:progress, "Slow", 3, 0, 0, 0]) # 0.1/s
        renderer.repaint
        expect(screen.content_rows.find { |r| r.include?("Slow") }).to include("<1/s")
      end

      it "hides the rate and ETA for a step expected to finish in under 2 seconds" do
        renderer.apply([:start, "Quick", "Quick"])
        renderer.apply([:progress_begin, "Quick", 100])
        at(1.2)
        renderer.apply([:progress, "Quick", 70, 0, 0, 0]) # ~58/s, ~0.5s left, ~1.7s total
        renderer.repaint

        row = screen.content_rows.find { |r| r.include?("Quick") }
        expect(row).to include("70%") # percent still shown
        expect(row).not_to include("/s") # no rate
        expect(row).not_to include("ETA") # no ETA
      end

      it "collapses to a permanent ✓ line on finish: a single total, no percent" do
        renderer.apply([:progress, "Categories", 4281, 0, 0, 0])
        at(12.0)
        renderer.apply([:finish, "Categories", :done])
        renderer.repaint

        rows = screen.content_rows
        expect(rows.first).to start_with("✓ Categories")
        expect(rows.first).to include("4,281")
        expect(rows.first).not_to include("/") # the count is not repeated as current/max
        expect(rows.first).not_to include("%") # no lingering percent
      end
    end

    describe "an indeterminate step (nil max_progress)" do
      it "renders a spinner and running count, with no percent or ETA" do
        renderer.apply([:start, "Uploads", "Uploads"])
        renderer.apply([:progress_begin, "Uploads", nil])
        at(3.0)
        renderer.apply([:progress, "Uploads", 33_474, 0, 0, 0])
        renderer.repaint

        row = screen.content_rows.first
        expect(row).to include("Uploads")
        expect(row).to include("33,474")
        expect(row).not_to include("%")
        expect(row).not_to include("ETA")
      end
    end

    describe "a step with a zero total (empty source)" do
      it "renders the count with no percent and never divides by zero" do
        renderer.apply([:start, "Empty", "Empty"])
        renderer.apply([:progress_begin, "Empty", 0])
        renderer.apply([:progress, "Empty", 0, 0, 0, 0])

        expect { renderer.repaint }.not_to raise_error
        row = screen.content_rows.first
        expect(row).to include("Empty")
        expect(row).not_to include("%")
      end
    end

    describe "the starting state (before with_progress)" do
      it "renders a counting… label" do
        renderer.apply([:start, "Posts", "Posts"])
        at(1.0)
        renderer.repaint

        expect(screen.content_rows.first).to include("counting…")
      end
    end

    describe "multiple concurrent steps" do
      it "renders one row per running step" do
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        renderer.apply([:start, "Tags", "Tags"])
        renderer.apply([:progress_begin, "Tags", 200])
        at(2.0)
        renderer.apply([:progress, "Posts", 400, 0, 0, 0])
        renderer.apply([:progress, "Tags", 50, 0, 0, 0])
        renderer.repaint

        rows = screen.content_rows
        expect(rows.find { |r| r.include?("Posts") }).to include("1,000") # totals, not current/max
        expect(rows.find { |r| r.include?("Tags") }).to include("200")
      end

      it "keeps steps with the same title independent (keyed on id, not title)" do
        renderer.apply([:start, 1, "Posts"])
        renderer.apply([:start, 2, "Posts"])
        renderer.apply([:progress_begin, 1, 1000])
        renderer.apply([:progress_begin, 2, 1000])
        renderer.apply([:progress, 1, 250, 0, 0, 0])
        renderer.apply([:progress, 2, 750, 0, 0, 0])
        renderer.repaint

        rows = screen.content_rows.select { |r| r.include?("Posts") }
        expect(rows.size).to eq(2)
        expect(rows.map { |r| r[/\d+%/] }).to contain_exactly("25%", "75%")
      end
    end

    describe "finish outcomes" do
      it "lists finished steps as permanent lines in completion order" do
        renderer.apply([:start, "Categories", "Categories"])
        renderer.apply([:progress_begin, "Categories", 10])
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 10])

        renderer.apply([:finish, "Users", :done])
        renderer.apply([:finish, "Categories", :done])
        renderer.repaint

        finished = screen.content_rows.select { |r| r.start_with?("✓") }
        expect(finished[0]).to include("Users")
        expect(finished[1]).to include("Categories")
      end

      it "marks a failed step with ✗ and a failed note, keeping its count" do
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        renderer.apply([:progress, "Posts", 410, 0, 0, 0])
        renderer.apply([:finish, "Posts", :failed])
        renderer.repaint

        row = screen.content_rows.first
        expect(row).to start_with("✗ Posts")
        expect(row).to include("failed")
        expect(row).to include("410") # how far it got
      end

      it "marks an interrupted step with an interrupted-at-N% note and no ✓" do
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        renderer.apply([:progress, "Posts", 410, 0, 0, 0])
        renderer.apply([:finish, "Posts", :interrupted])
        renderer.repaint

        row = screen.content_rows.first
        expect(row).to include("Posts")
        expect(row).to include("interrupted at 41%")
        expect(row).not_to start_with("✓")
      end

      it "drops a finished step from the model so it isn't re-scanned each frame" do
        renderer.apply([:start, "Done", "Done"])
        renderer.apply([:progress_begin, "Done", 10])
        renderer.apply([:finish, "Done", :done])

        expect(renderer.instance_variable_get(:@steps)).to be_empty
      end

      it "collapses a still-running step to interrupted on finalize" do
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        renderer.apply([:progress, "Posts", 250, 0, 0, 0])
        renderer.finalize

        expect(screen.content_rows.first).to include("interrupted at 25%")
      end
    end

    describe "annotations" do
      it "shows warning/error/skip counts only when greater than zero" do
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 100])
        at(1.0)
        renderer.apply([:progress, "Users", 40, 0, 0, 0])
        renderer.repaint
        expect(screen.content_rows.first).not_to match(/warning|error|skip/)

        renderer.apply([:progress, "Users", 60, 2, 3, 1])
        renderer.repaint
        row = screen.content_rows.first
        expect(row).to include("3 warnings")
        expect(row).to include("1 error")
        expect(row).to include("2 skips")
      end

      it "groups large annotation counts with thousands separators" do
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 1_000_000])
        at(1.0)
        renderer.apply([:progress, "Users", 500_000, 174_464, 0, 0])
        renderer.repaint
        expect(screen.content_rows.first).to include("174,464 skips")
      end
    end

    describe "notices" do
      it "renders a permanent line prefixed with the step title" do
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:notice, "Posts", "Calculating items took 6 seconds"])
        renderer.repaint

        notice = screen.content_rows.find { |r| r.include?("Calculating items") }
        expect(notice).to start_with("Posts")
      end

      it "renders an unattributed notice when there is no step title" do
        renderer.apply([:notice, nil, "Run starting"])
        renderer.repaint
        expect(screen.content_rows).to include("Run starting")
      end
    end

    describe "count and time column alignment" do
      it "right-aligns finished counts into a fixed column" do
        [["Small", 5], ["Big", 1_000_000]].each do |title, total|
          renderer.apply([:start, title, title])
          renderer.apply([:progress_begin, title, total])
          renderer.apply([:progress, title, total, 0, 0, 0])
          renderer.apply([:finish, title, :done])
        end
        renderer.repaint

        rows = screen.content_rows
        small = rows.find { |r| r.include?("Small") }
        big = rows.find { |r| r.include?("Big") }
        # the count is right-aligned, so the duration after it starts at the same
        # screen column in both rows
        expect(small.index("0:00")).to eq(big.index("0:00"))
        expect(small.index("0:00")).to be > big.index("Big")
      end

      it "reserves the title column so rows with different-length titles align" do
        titles = ["Short", "A considerably longer step title"]
        narrow = described_class.new(output: io, width: 130, clock: -> { time[0] }, titles:)
        titles.each do |title|
          narrow.apply([:start, title, title])
          narrow.apply([:progress_begin, title, 1000])
          narrow.apply([:progress, title, 1000, 0, 0, 0])
          narrow.apply([:finish, title, :done])
        end
        narrow.repaint

        rows = screen.content_rows
        short = rows.find { |r| r.include?("Short") }
        long = rows.find { |r| r.include?("longer") }
        expect(short.index("1,000")).to eq(long.index("1,000"))
      end

      it "caps an over-long title with an ellipsis so the columns still fit" do
        long = "A really, really, really long step title that keeps going"
        renderer.apply([:start, 1, long])
        renderer.apply([:progress_begin, 1, 1000])
        renderer.apply([:progress, 1, 500, 0, 0, 0])
        renderer.repaint

        row = screen.content_rows.first
        expect(row).to include("…") # title elided
        expect(row).not_to include("keeps going") # tail dropped
        expect(row).to include("50%") # columns still render
        expect(row).to include("1,000")
      end

      it "puts a running step's total in the same column as finished totals" do
        renderer.apply([:start, "Done step", "Done step"])
        renderer.apply([:progress_begin, "Done step", 4281])
        renderer.apply([:progress, "Done step", 4281, 0, 0, 0])
        renderer.apply([:finish, "Done step", :done])
        renderer.apply([:start, "Running step", "Running step"])
        renderer.apply([:progress_begin, "Running step", 1_000_000])
        renderer.apply([:progress, "Running step", 250_000, 0, 0, 0])
        renderer.repaint

        rows = screen.content_rows
        done = rows.find { |r| r.include?("Done step") }
        running = rows.find { |r| r.include?("Running step") }
        expect(done.index("4,281") + "4,281".length).to eq(
          running.index("1,000,000") + "1,000,000".length,
        )
      end

      it "shows long runtimes as H:MM:SS" do
        renderer.apply([:start, "Slow", "Slow"])
        renderer.apply([:progress_begin, "Slow", 100])
        renderer.apply([:progress, "Slow", 50, 0, 0, 0])
        at(7253.0) # 2h 0m 53s
        renderer.repaint
        expect(screen.content_rows.first).to include("2:00:53")
      end
    end

    describe "out-of-order updates" do
      it "ignores progress for a step that already finished" do
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 100])
        renderer.apply([:progress, "Users", 100, 0, 0, 0])
        renderer.apply([:finish, "Users", :done])
        renderer.repaint
        before = screen.to_s

        renderer.apply([:progress, "Users", 200, 9, 9, 9]) # late, must be ignored
        renderer.repaint

        expect(screen.to_s).to eq(before)
      end
    end

    describe "NO_COLOR" do
      around do |example|
        original = ENV["NO_COLOR"]
        ENV["NO_COLOR"] = "1"
        example.run
        original.nil? ? ENV.delete("NO_COLOR") : ENV["NO_COLOR"] = original
      end

      it "emits no SGR color sequences" do
        renderer = described_class.new(output: io, width: 120, clock: -> { time[0] })
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 100])
        renderer.apply([:progress, "Users", 40, 0, 1, 0])
        renderer.repaint
        renderer.apply([:finish, "Users", :done])
        renderer.repaint

        expect(io.string).not_to match(/\e\[[0-9;]*m/)
      end
    end

    describe "the no-line-reaches-width invariant" do
      it "keeps every rendered line strictly narrower than the terminal" do
        narrow = described_class.new(output: io, width: 40, clock: -> { time[0] })
        narrow.apply(
          [
            :start,
            "A step with a deliberately long title here",
            "A step with a deliberately long title here",
          ],
        )
        narrow.apply([:progress_begin, "A step with a deliberately long title here", 1_234_567])
        at(5.0)
        narrow.apply([:progress, "A step with a deliberately long title here", 1_000_000, 5, 5, 5])
        narrow.repaint
        narrow.apply([:notice, "A step with a deliberately long title here", "x" * 100])
        narrow.repaint

        AnsiScreen
          .new(width: 40)
          .feed(io.string)
          .rows
          .each do |row|
            expect(AnsiScreen.display_width(row)).to be <= 38 # width - 2
          end
      end
    end
  end

  # Facade-level behaviour exercises the real queue + render thread. Each test
  # drives the producer side through step handles, then `close` (which drains,
  # finalizes, and joins the render thread) makes the final screen deterministic.
  describe "the facade and render thread" do
    subject(:reporter) { described_class.new(fps: 60, output: io) }

    let(:io) { StringIO.new }

    def final_screen
      AnsiScreen.new(width: 200).feed(io.string)
    end

    it "accumulates update deltas exactly under concurrent producers" do
      step = reporter.start_step("Users")
      step.with_progress(max_progress: 800) do |progress|
        threads =
          8.times.map do
            Thread.new { 100.times { progress.update(increment_by: 1, warning_count: 1) } }
          end
        threads.each(&:join)
      end
      step.finish
      reporter.close

      row = final_screen.content_rows.find { |r| r.start_with?("✓ Users") }
      expect(row).to include("800")
      expect(row).to include("800 warnings")
    end

    it "renders an interrupted line when finish runs during a SignalException" do
      step = reporter.start_step("Posts")
      step.with_progress(max_progress: 1000) { |progress| progress.update(increment_by: 410) }
      begin
        raise Interrupt
      rescue Interrupt
        step.finish # `$!` is the Interrupt here
      end
      reporter.close

      expect(final_screen.content_rows.first).to include("interrupted at 41%")
    end

    it "renders a ✗ line when finish runs during an ordinary exception" do
      step = reporter.start_step("Posts")
      step.with_progress(max_progress: 1000) { |progress| progress.update(increment_by: 410) }
      begin
        raise "boom"
      rescue StandardError
        step.finish
      end
      reporter.close

      expect(final_screen.content_rows.first).to start_with("✗ Posts")
    end

    it "is safe to close more than once and restores the cursor" do
      reporter.start_step("Users").finish
      reporter.close
      expect { reporter.close }.not_to raise_error
      expect(io.string).to end_with(Migrations::Reporting::Tui::Ansi::SHOW_CURSOR)
    end
  end
end
