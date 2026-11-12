# frozen_string_literal: true

module Migrations
  module Reporting
    # Picks the reporter for a run. {Tui}, with its live progress region, needs a
    # real terminal. Everything else (pipes, CI, and dumb terminals) gets the
    # line-based {Plain}. To force plain output on a real terminal, set
    # `TERM=dumb`.
    module Factory
      def self.build(output: $stdout, titles: [])
        if plain?(output)
          Plain.new(output:)
        else
          Tui.new(output:, titles:)
        end
      end

      def self.plain?(output)
        return true unless output.respond_to?(:tty?) && output.tty?

        term = ENV["TERM"].to_s
        term.empty? || term == "dumb"
      end
    end
  end
end
