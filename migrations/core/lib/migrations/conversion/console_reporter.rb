# frozen_string_literal: true

module Migrations
  module Conversion
    # Renders step execution as sequential console output: the step title,
    # indented notices, and one `ExtendedProgressBar` per `with_progress`
    # call. It has no state and no synchronization because only one step —
    # and therefore one progress bar — runs at a time.
    class ConsoleReporter < StepReporter
      def start_step(title)
        puts title
      end

      def notice(message)
        puts "    #{message}"
      end

      def with_progress(max_progress:, &block)
        ExtendedProgressBar.new(max_progress:).run(&block)
      end
    end
  end
end
