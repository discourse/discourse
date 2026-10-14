# frozen_string_literal: true

require "colored2"

module Migrations
  module Importer
    module Customizations
      # Collects one outcome per item and prints the summary.
      class Report
        Entry = Data.define(:section, :label, :status, :message)

        STATUSES = %i[exported changed unchanged skipped failed].freeze

        attr_reader :entries

        def initialize(output: $stdout)
          @output = output
          @entries = []
        end

        # Runs the block for one item; an exception marks only that item failed.
        # The block returns a status, or `[status, message]`.
        def item(section, label)
          status, message = yield
          add(section, label, status, message)
        rescue SkipItem => e
          add(section, label, :skipped, e.message)
        rescue StandardError => e
          add(section, label, :failed, "#{e.class.name.demodulize}: #{e.message}")
        end

        def add(section, label, status, message = nil)
          raise ArgumentError, "unknown status #{status.inspect}" if STATUSES.exclude?(status)

          entry = Entry.new(section:, label:, status:, message:)
          @entries << entry
          print_entry(entry)
          entry
        end

        def failed?
          @entries.any? { |entry| entry.status == :failed }
        end

        def counts
          STATUSES.index_with { |status| @entries.count { |entry| entry.status == status } }
        end

        def print_summary
          @output.puts
          @output.puts counts.map { |status, count| "#{status}: #{count}" }.join(", ")
        end

        private

        def print_entry(entry)
          line = "#{entry.status.to_s.ljust(9)} #{entry.section}: #{entry.label}"
          line += " (#{entry.message})" if entry.message.present?
          @output.puts colorize(entry.status, line)
        end

        def colorize(status, line)
          case status
          when :changed, :exported
            line.green
          when :skipped
            line.yellow
          when :failed
            line.red
          else
            line
          end
        end
      end
    end
  end
end
