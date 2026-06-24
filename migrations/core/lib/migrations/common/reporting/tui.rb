# frozen_string_literal: true

module Migrations
  module Reporting
    # A terminal reporter. It draws a live progress row for each running step
    # (spinner, percent, count, elapsed time, ETA, and rate) at the bottom of the
    # screen. Notices and finished steps print above and scroll up into the normal
    # terminal history.
    #
    # The code that reports progress never draws anything itself. This class is a
    # thread-safe front end: each call only adds an event to a queue. A separate
    # thread reads the queue, updates the model, and redraws at a fixed rate. That
    # is what lets one thread report progress while another one started the step,
    # without the output getting mixed up.
    #
    # The drawing itself is in {Renderer}. It runs on one thread only and has no
    # side effects apart from its output and clock (both can be injected), so it
    # can be tested without threads or a real terminal.
    class Tui < Reporter
      def initialize(fps: 10, output: $stdout, titles: [])
        super()
        @queue = Thread::Queue.new
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

      def report_progress(id, current, skip_count, warning_count, error_count)
        enqueue([:progress, id, current, skip_count, warning_count, error_count])
      end

      def report_finish(id, outcome)
        enqueue([:finish, id, outcome])
      end

      def close
        return if @closed
        @closed = true
        enqueue([:close])
        @render_thread.join

        # The render loop's `ensure` already restored the terminal. If the loop
        # crashed, report it here so it isn't lost. Don't raise: `close` itself
        # runs inside the run's `ensure`.
        return unless @render_error

        warn("TUI reporter crashed: #{@render_error.class}: #{@render_error.message}")
        warn(@render_error.backtrace.first(5).join("\n")) if @render_error.backtrace
      end

      private

      # If the render thread has died, drop the event. Otherwise a crashed
      # renderer would let the queue grow without limit for the rest of the run.
      def enqueue(event)
        @queue << event if @render_thread.nil? || @render_thread.alive?
      end

      def render_loop
        # Redraw on a terminal resize while we run; the ensure below puts the
        # previous handler back.
        @winch_prev = Signal.trap("WINCH") { @renderer.mark_resize }
        @renderer.on_start
        run_frames
      rescue StandardError => e
        @render_error = e
      ensure
        Signal.trap("WINCH", @winch_prev || "DEFAULT")
        @renderer.finalize
      end

      # Draws a frame at a steady rate until the close event arrives. Each frame
      # drains the queued events, handles a pending resize, repaints, then sleeps
      # for the rest of the frame's time.
      def run_frames
        loop do
          frame_started_at = monotonic
          break if drain_until_close
          @renderer.consume_resize
          @renderer.repaint
          sleep_rest_of_frame(frame_started_at)
        end
      end

      # Sleeps for whatever is left of this frame's time, so repaints happen at a
      # steady rate instead of as fast as the loop can spin.
      def sleep_rest_of_frame(frame_started_at)
        remaining = @frame - (monotonic - frame_started_at)
        sleep(remaining) if remaining > 0
      end

      def drain_until_close
        until @queue.empty?
          event = @queue.pop(true)
          return true if event[0] == :close
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
