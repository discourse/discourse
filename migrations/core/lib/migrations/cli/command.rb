# frozen_string_literal: true

require "samovar"

module Migrations
  module CLI
    # Base class for all `disco` commands. Commands that need a booted Rails
    # environment declare `requires_rails!`; the binary boots Rails only after
    # such a command has been selected, keeping help and Rails-free commands
    # fast.
    class Command < Samovar::Command
      # Raised by {#require_positional!} when a required positional is missing.
      class MissingPositionalError < StandardError
        include PresentableError
      end

      # Coerces a comma-separated `--only`/`--skip` value into a list of
      # normalized step names. Shared as the `type:` for those options.
      STEP_LIST = ->(value) do
        value.to_s.split(",").map { |name| name.strip.demodulize.underscore }
      end

      def self.requires_rails!
        @requires_rails = true
      end

      def self.requires_rails?
        return true if @requires_rails == true
        superclass.respond_to?(:requires_rails?) && superclass.requires_rails?
      end

      # Samovar parses each declaration once, front-to-back, and only matches
      # options at the front of the remaining input — so by default options must
      # precede positionals (`convert --only x discourse`). Hoist any recognized
      # option flags (and their values) to the front so they may also appear
      # after positionals (`convert discourse --only x`), the way the previous
      # Thor-based CLI allowed. Everything after a `--` separator is left as-is.
      def parse(input)
        # Reorder in place: Samovar consumes the input array by reference (nested
        # commands rely on it being emptied), so we must mutate it rather than
        # pass a copy.
        input.replace(hoist_options(input))
        super(input)
      end

      private

      # Samovar can't enforce required positionals: `one :x, required: true`
      # raises during parsing, before `call` runs, which would break the
      # `-h/--help` handling. Commands validate required positionals at the
      # top of `call` with this helper instead.
      def require_positional!(value, name, hint: nil)
        return value unless value.nil?

        message = +"Missing required argument: <#{name}>"
        message << "\n#{hint}" if hint
        raise MissingPositionalError, message
      end

      def hoist_options(input)
        options = self.class.table.merged[:options]
        return input unless options

        takes_value = {}
        options.each do |option|
          option.flags.each do |flag|
            [flag.prefix, *Array(flag.alternatives)].each do |prefix|
              takes_value[prefix] = !flag.boolean?
            end
          end
        end

        flags = []
        positionals = []
        index = 0

        while index < input.size
          token = input[index]

          if token == "--"
            positionals.concat(input[index..])
            break
          elsif takes_value.key?(token)
            flags << token
            if takes_value[token] && index + 1 < input.size
              flags << input[index + 1]
              index += 1
            end
          else
            positionals << token
          end

          index += 1
        end

        flags + positionals
      end
    end
  end
end
