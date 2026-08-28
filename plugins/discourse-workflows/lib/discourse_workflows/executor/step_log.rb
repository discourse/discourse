# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class StepLog
      MAX_ENTRIES = 200

      attr_reader :entries

      def initialize
        @entries = []
        @has_errors = false
        @has_warnings = false
        @truncated = false
      end

      def info(message)
        append("info", message: message)
      end

      def warn(message)
        append("warn", message: message)
      end

      def error(message)
        append("error", message: message)
      end

      def kv(key, value, level: "info")
        append(level, key: key, value: value.to_s)
      end

      def errors?
        @has_errors
      end

      def warnings?
        @has_warnings
      end

      def empty?
        @entries.empty?
      end

      def present?
        @entries.present?
      end

      def merge(other)
        return unless other
        other.entries.each do |entry|
          if @entries.size >= MAX_ENTRIES - 1
            unless @truncated
              @truncated = true
              @entries << {
                "level" => "warn",
                "at" => Time.current.utc.iso8601,
                "message" => "Log truncated at #{MAX_ENTRIES} entries",
              }
            end
            break
          end
          record(entry)
        end
      end

      def as_json(*)
        @entries
      end

      def error_summary
        errors = @entries.select { |e| e["level"] == "error" }
        return if errors.empty?
        messages = errors.first(3).map { |e| e["message"] || "#{e["key"]}: #{e["value"]}" }
        messages.join("; ").truncate(500)
      end

      private

      def append(level, **fields)
        if @entries.size >= MAX_ENTRIES - 1
          unless @truncated
            @truncated = true
            @entries << {
              "level" => "warn",
              "at" => Time.current.utc.iso8601,
              "message" => "Log truncated at #{MAX_ENTRIES} entries",
            }
          end
          return
        end
        record(
          { "level" => level, "at" => Time.current.utc.iso8601 }.merge(
            fields.transform_keys(&:to_s),
          ),
        )
      end

      def record(entry)
        @has_errors = true if entry["level"] == "error"
        @has_warnings = true if entry["level"] == "warn"
        @entries << entry
      end
    end
  end
end
