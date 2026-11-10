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
        expect(row).to include("46%") # 2000 / 4281, floored
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

      it "includes the counting time before progress_begin in the step's duration" do
        renderer.apply([:start, "Posts", "Posts"]) # the clock reads 6.0 here
        at(11.0) # planning/counting takes 5s before the progress bar starts
        renderer.apply([:progress_begin, "Posts", 100])
        at(13.0)
        renderer.apply([:progress, "Posts", 100, 0, 0, 0])
        renderer.apply([:finish, "Posts", :done])
        renderer.repaint

        row = screen.content_rows.find { |r| r.include?("Posts") }
        expect(row).to include("0:07") # 5s counting + 2s work, not just the 2s
      end

      it "does not read 100% until the very last item — floors, never rounds up" do
        renderer.apply([:progress, "Categories", 4280, 0, 0, 0]) # 4280/4281 = 99.98%
        at(8.0)
        renderer.repaint
        expect(screen.content_rows.first).to include(" 99%")
        expect(screen.content_rows.first).not_to include("100%")

        renderer.apply([:progress, "Categories", 4281, 0, 0, 0]) # done
        renderer.repaint
        expect(screen.content_rows.first).to include("100%")
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

    describe "the concurrency indicator" do
      let(:count_indicator) { /\d+×/ }

      def running_step(title, concurrency)
        renderer.apply([:start, title, title])
        renderer.apply([:progress_begin, title, 1000])
        renderer.apply([:concurrency, title, concurrency]) if concurrency
        renderer.apply([:progress, title, 500, 0, 0, 0])
      end

      it "renders the fork count, e.g. 4×, for a step using more than one fork" do
        running_step("Posts", 4)
        renderer.repaint
        expect(screen.content_rows.first).to include("4×")
      end

      it "shows nothing in the column for a single-fork step" do
        running_step("Posts", 1)
        renderer.repaint
        expect(screen.content_rows.first).not_to match(count_indicator)
      end

      it "shows nothing when the step never reports a count" do
        running_step("Posts", nil)
        renderer.repaint
        expect(screen.content_rows.first).not_to match(count_indicator)
      end

      it "updates the count live when it's re-reported" do
        running_step("Posts", 8)
        renderer.repaint
        expect(screen.content_rows.first).to include("8×")

        renderer.apply([:concurrency, "Posts", 2])
        renderer.repaint
        row = screen.content_rows.first
        expect(row).to include("2×")
        expect(row).not_to include("8×")
      end

      it "colors the count when color is on" do
        running_step("Posts", 8)
        renderer.repaint
        expect(io.string).to include("#{Migrations::Reporting::Tui::Ansi::MAGENTA}8×")
      end

      it "does not affect the count column shared with finished rows" do
        renderer.apply([:start, "Done", "Done"])
        renderer.apply([:progress_begin, "Done", 1_000_000])
        renderer.apply([:progress, "Done", 1_000_000, 0, 0, 0])
        renderer.apply([:finish, "Done", :done])
        running_step("Busy", 8)
        renderer.repaint

        rows = screen.content_rows
        done = rows.find { |r| r.include?("Done") }
        busy = rows.find { |r| r.include?("Busy") }
        # the count sits after the shared columns, so the totals still line up
        expect(busy.index("1,000") + "1,000".length).to eq(
          done.index("1,000,000") + "1,000,000".length,
        )
      end

      describe "without color" do
        around do |example|
          original = ENV["NO_COLOR"]
          ENV["NO_COLOR"] = "1"
          example.run
          original.nil? ? ENV.delete("NO_COLOR") : ENV["NO_COLOR"] = original
        end

        it "renders the count as plain text, with no color codes" do
          no_color = described_class.new(output: io, width: 120, clock: -> { time[0] })
          no_color.apply([:start, "Posts", "Posts"])
          no_color.apply([:progress_begin, "Posts", 1000])
          no_color.apply([:concurrency, "Posts", 8])
          no_color.apply([:progress, "Posts", 500, 0, 0, 0])
          no_color.repaint

          expect(screen.content_rows.first).to include("8×")
          expect(io.string).not_to include(Migrations::Reporting::Tui::Ansi::MAGENTA)
        end
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

      it "renders a notice with no owning step" do
        renderer.apply([:notice, nil, "Run starting"])
        renderer.repaint
        expect(screen.content_rows).to include("Run starting")
      end

      it "splits a multi-line notice so it can't fuse with or strand the live rows" do
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        renderer.apply([:start, "Tags", "Tags"])
        renderer.apply([:progress_begin, "Tags", 200])
        at(1.0)
        renderer.apply([:progress, "Posts", 100, 0, 0, 0])
        renderer.apply([:progress, "Tags", 20, 0, 0, 0])
        renderer.repaint

        renderer.apply([:notice, "Posts", "RuntimeError: boom\n  from a.rb:1\n  from b.rb:2"])
        at(2.0)
        renderer.apply([:progress, "Posts", 300, 0, 0, 0])
        renderer.repaint
        at(3.0)
        renderer.apply([:progress, "Posts", 500, 0, 0, 0])
        renderer.repaint

        rows = screen.content_rows
        # Each notice line landed as its own permanent row.
        expect(rows).to include(a_string_matching(/RuntimeError: boom/))
        expect(rows).to include(a_string_matching(/from a\.rb:1/))
        expect(rows).to include(a_string_matching(/from b\.rb:2/))
        # No permanent notice text is fused onto a live row's percent.
        expect(rows).to(be_none { |r| r.include?("from ") && r.match?(/%/) })
        # The two live rows appear exactly once each — nothing stranded above.
        expect(rows.count { |r| r.match?(/Posts.*%/) }).to eq(1)
        expect(rows.count { |r| r.match?(/Tags.*%/) }).to eq(1)
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
        expect(small.index("<1s")).to eq(big.index("<1s"))
        expect(small.index("<1s")).to be > big.index("Big")
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

    describe "repaint leftover accounting" do
      def two_live_steps
        renderer.apply([:start, "Posts", "Posts"])
        renderer.apply([:progress_begin, "Posts", 1000])
        renderer.apply([:start, "Tags", "Tags"])
        renderer.apply([:progress_begin, "Tags", 200])
        at(2.0)
        renderer.apply([:progress, "Posts", 400, 0, 0, 0])
        renderer.apply([:progress, "Tags", 50, 0, 0, 0])
      end

      it "emits no extra newlines when a frame both prints permanents and shrinks the live region" do
        two_live_steps
        renderer.repaint

        mark = io.string.length
        renderer.apply([:finish, "Posts", :done])
        renderer.apply([:finish, "Tags", :done])
        renderer.repaint

        frame = io.string[mark..]
        # Two permanent lines replace the two live rows: only their two newlines,
        # not extra leftover erase pairs for a region that didn't actually shrink.
        expect(frame.scan("\r\n").size).to eq(2)
      end

      it "leaves no stray blank rows below the interrupted lines on finalize" do
        two_live_steps
        renderer.repaint
        renderer.finalize

        rows = screen.rows
        interrupted = rows.select { |r| r.include?("interrupted") }
        expect(interrupted.size).to eq(2)
        # Only the cursor's resting line sits below them, not a blank per shrunk row.
        expect(rows[(rows.index(interrupted.last) + 1)..].reject(&:empty?)).to be_empty
        expect(rows.count(&:empty?)).to eq(1)
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

    describe "NO_COLOR set to an empty string" do
      around do |example|
        original = ENV["NO_COLOR"]
        ENV["NO_COLOR"] = ""
        example.run
        original.nil? ? ENV.delete("NO_COLOR") : ENV["NO_COLOR"] = original
      end

      it "still emits color, since NO_COLOR only disables it when non-empty" do
        renderer = described_class.new(output: io, width: 120, clock: -> { time[0] })
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 100])
        renderer.apply([:progress, "Users", 40, 0, 0, 0])
        renderer.repaint

        expect(io.string).to match(/\e\[[0-9;]*m/)
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

    describe "the finishing-up status and run summary" do
      it "shows a transient finishing-up line while draining, replaced by the summary" do
        renderer.apply([:finalizing_begin])
        renderer.repaint
        expect(screen.content_rows).to include(a_string_matching(/Finishing up/))

        # the real flow ends `finalizing` and prints the summary in the same frame
        renderer.apply([:finalizing_end])
        renderer.apply([:summary, 5.0, 3, 0, 0])
        renderer.repaint
        expect(screen.content_rows).not_to include(a_string_matching(/Finishing up/))
        expect(screen.content_rows).to include(a_string_matching(/Total.*3 steps/))
      end

      it "prints a summary with the runtime under the step-duration column" do
        renderer.apply([:start, "Users", "Users"])
        renderer.apply([:progress_begin, "Users", 1000])
        renderer.apply([:progress, "Users", 1000, 0, 0, 0])
        at(3.0)
        renderer.apply([:finish, "Users", :done])
        renderer.apply([:summary, 138.0, 24, 0, 0])
        renderer.repaint

        summary = screen.content_rows.find { |r| r.include?("Total") }
        step = screen.content_rows.find { |r| r.include?("Users") }
        expect(summary).to include("24 steps")
        expect(summary).to include("2:18") # 138 seconds runtime
        # the runtime lines up under the per-step durations
        expect(summary.index(/\d+:\d\d/)).to eq(step.index(/\d+:\d\d/))
      end

      it "notes failed and skipped steps in the summary" do
        renderer.apply([:summary, 60.0, 24, 2, 1])
        renderer.repaint

        row = screen.content_rows.find { |r| r.include?("Total") }
        expect(row).to include("2 failed")
        expect(row).to include("1 skipped")
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

    it "coalesces progress instead of queuing one event per update" do
      step = reporter.start_step("Users")
      queue = reporter.instance_variable_get(:@queue)

      step.with_progress(max_progress: 10_000) do |progress|
        10_000.times { progress.update(increment_by: 1) }
        # the 10k updates collapse into one coalesced slot, so the queue never
        # fills and the render thread keeps repainting
        expect(queue.size).to be < 50
      end
      step.finish
      reporter.close

      row = final_screen.content_rows.find { |r| r.start_with?("✓ Users") }
      expect(row).to include("10,000")
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

    it "does not raise, and warns, when the render thread's output breaks" do
      broken = Object.new
      def broken.write(*)
        raise Errno::EPIPE
      end

      def broken.flush
      end

      reporter = described_class.new(fps: 60, output: broken)
      reporter.start_step("Users").finish

      expect { reporter.close }.to output(/TUI reporter crashed/).to_stderr
    end

    it "drops a coalesced progress report that lands after its step finished" do
      # `apply_coalesced_progress` is private and normally only runs on the render
      # thread; expose it through a subclass to drive a frame by hand.
      reporter =
        Class.new(described_class) { public :apply_coalesced_progress }.new(fps: 60, output: io)
      reporter.start_step("Users").finish
      reporter.close # drains the finish and joins the render thread

      # A worker races the finish and reports progress for the now-finished step.
      reporter.report_progress(1, 50, 0, 0, 0)
      expect(reporter.instance_variable_get(:@progress)).not_to be_empty

      # The next frame swaps the map out, so the stale entry can't linger and be
      # re-applied as a no-op on every frame for the rest of the run.
      reporter.apply_coalesced_progress
      expect(reporter.instance_variable_get(:@progress)).to be_empty
    end
  end
end
