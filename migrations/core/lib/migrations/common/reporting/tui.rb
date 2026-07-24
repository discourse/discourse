# frozen_string_literal: true

module Migrations
  module Reporting
    # A terminal reporter. It draws a live progress row for each running step
    # (spinner, percent, count, elapsed time, ETA, and rate) at the bottom of the
    # screen. Notices and finished steps print above and scroll up into the normal
    # terminal history.
    #
    # The code that reports progress never draws anything itself. This class is a
    # thread-safe front end: callers only hand off events. A separate thread
    # applies them, updates the model, and redraws at a fixed rate. That lets one
    # thread report progress while another started the step, without the output
    # getting mixed up.
    #
    # The drawing itself is in {Renderer}. It runs on one thread only and has no
    # side effects apart from its output and clock (both can be injected), so it
    # can be tested without threads or a real terminal.
    class Tui < Reporter
      # How long `close` waits for the render thread to drain before killing it.
      CLOSE_TIMEOUT = 5
      private_constant :CLOSE_TIMEOUT

      def initialize(fps: 10, output: $stdout, titles: [])
        raise ArgumentError, "fps must be greater than 0" if fps <= 0

        super()
        @queue = Thread::Queue.new
        @progress = {}
        @progress_mutex = Mutex.new
        @output = output
        @renderer = Renderer.new(output:, titles:)
        @frame = 1.0 / fps
        @closed = false
        @render_error = nil
        @render_thread = Thread.new { render_loop }
        @render_thread.name = "tui_reporter"
        @render_thread.report_on_exception = false # render_loop catches it; close reports it
      end

      # --- The {Reporter} methods. {StepHandle} calls them from other threads. ---

      def report_start(id, title)
        enqueue([:start, id, title])
      end

      def report_notice(id, message)
        enqueue([:notice, id, message])
      end

      def report_progress_begin(id, max_progress)
        enqueue([:progress_begin, id, max_progress])
      end

      def report_concurrency(id, count)
        enqueue([:concurrency, id, count])
      end

      def report_progress(id, current, skip_count, warning_count, error_count)
        # Progress is coalesced, not queued: one event per row across many steps
        # would keep the queue full and starve the repaint. Keep the latest only.
        @progress_mutex.synchronize do
          @progress[id] = [current, skip_count, warning_count, error_count]
        end
      end

      def report_finish(id, outcome)
        enqueue([:finish, id, outcome])
      end

      def report_finalizing_begin
        enqueue([:finalizing_begin])
      end

      def report_finalizing_end
        enqueue([:finalizing_end])
      end

      def report_summary(runtime:, total:, failed:, skipped:)
        enqueue([:summary, runtime, total, failed, skipped])
      end

      def close
        return if @closed
        @closed = true
        enqueue([:close])

        if @render_thread.join(CLOSE_TIMEOUT).nil?
          # The render thread is wedged (e.g. blocked in `write` on a stopped
          # tty). `close` runs inside the run's `ensure`, so it must not hang.
          @render_thread.kill
          warn("TUI reporter did not stop in time and was killed.")
          show_cursor_best_effort
        end

        report_render_error
      end

      private

      # If the render thread has died, drop the event. Otherwise a crashed
      # renderer would let the queue grow without limit for the rest of the run.
      def enqueue(event)
        @queue << event if @render_thread.nil? || @render_thread.alive?
      end

      def render_loop
        # Redraw on a terminal resize while we run; the ensure below puts the
        # previous handler back. Some platforms have no WINCH signal, where
        # `Signal.trap` raises — run without resize support rather than crash.
        begin
          @winch_prev = Signal.trap("WINCH") { @renderer.mark_resize }
          @winch_installed = true
        rescue StandardError
          @winch_installed = false
        end

        @renderer.on_start
        run_frames
      rescue Exception => e
        # The thread boundary: nothing may escape, or `close`'s `join` would
        # re-raise it inside the run's `ensure`. Fatal errors land in the render
        # error report like everything else.
        @render_error = e
      ensure
        # Two independent steps: a failure restoring the trap must not skip the
        # terminal restore, and vice versa. Neither may raise out of the ensure.
        restore_winch_trap
        finalize_renderer
      end

      def restore_winch_trap
        Signal.trap("WINCH", @winch_prev || "DEFAULT") if @winch_installed
      rescue StandardError
        nil
      end

      def finalize_renderer
        @renderer.finalize
      rescue StandardError => e
        @render_error ||= e
      end

      # The render loop's `ensure` already restored the terminal. If the loop
      # crashed, report it here so it isn't lost. Don't raise: `close` runs
      # inside the run's `ensure`.
      def report_render_error
        return unless @render_error

        warn("TUI reporter crashed: #{@render_error.class}: #{@render_error.message}")
        warn(@render_error.backtrace.first(5).join("\n")) if @render_error.backtrace
      end

      # `write_nonblock`: the render thread was most likely killed because it was
      # blocked writing to this same output, so a plain `write` here could block
      # `close` all over again.
      def show_cursor_best_effort
        @output.write_nonblock(Ansi::SHOW_CURSOR)
      rescue StandardError
        nil
      end

      # Draws a frame at a steady rate until the close event arrives. Each frame
      # drains the queued events, handles a pending resize, repaints, then sleeps
      # for the rest of the frame's time.
      def run_frames
        loop do
          frame_started_at = monotonic
          break if drain_until_close
          apply_coalesced_progress
          @renderer.consume_resize
          @renderer.repaint
          sleep_rest_of_frame(frame_started_at)
        end
      end

      # Take the whole map and leave a fresh one behind, so a progress report
      # racing its step's `:finish` can't linger and be re-applied as a no-op on
      # every frame for the rest of the run. A finishing step still sees its last
      # value: the drain (and its `flush_progress`) runs before this swap.
      def apply_coalesced_progress
        snapshot =
          @progress_mutex.synchronize do
            current = @progress
            @progress = {}
            current
          end
        snapshot.each { |id, values| @renderer.apply([:progress, id, *values]) }
      end

      def flush_progress(id)
        values = @progress_mutex.synchronize { @progress.delete(id) }
        @renderer.apply([:progress, id, *values]) if values
      end

      # Sleeps for whatever is left of this frame's time, so repaints happen at a
      # steady rate instead of as fast as the loop can spin.
      def sleep_rest_of_frame(frame_started_at)
        remaining = @frame - (monotonic - frame_started_at)
        sleep(remaining) if remaining > 0
      end

      def drain_until_close
        # Drain only what's already queued; events arriving while we drain wait
        # for the next frame, so a burst can't keep the loop here and starve the
        # repaint.
        @queue.size.times do
          event = @queue.pop(true)
          return true if event[0] == :close
          flush_progress(event[1]) if event[0] == :finish
          @renderer.apply(event)
        end
        false
      rescue ThreadError
        false
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
