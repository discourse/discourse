# frozen_string_literal: true

require "json"

module DiscourseAi
  module Evals
    class StructuredLogger
      attr_reader :root, :path

      def initialize(path)
        @root = nil
        @path = path
      end

      def start_root(name:, args: {})
        raise ArgumentError, "root already started" if root

        @root = build_step(name: name, args: args)
      end

      def root_started?
        !root.nil?
      end

      def add_child_step(name:, args: {})
        ensure_root!
        child = build_step(name: name, args: args)
        root[:children] << child
        child
      end

      def append_entry(step:, name:, args: {}, started_at: nil, ended_at: nil)
        entry = {
          name: name,
          args: args || {},
          start_time: started_at || current_time,
          end_time: ended_at || started_at || current_time,
        }

        step[:entries] << entry
        entry
      end

      def finish_root(end_time: nil)
        ensure_root!
        root[:end_time] = end_time || current_time
      end

      def to_trace_event_json
        ensure_root!

        trace_events = []
        emit_step(root, trace_events)
        JSON.pretty_generate({ traceEvents: trace_events })
      end

      def save(path)
        File.write(path, to_trace_event_json)
      end

      def as_json
        ensure_root!
        root
      end

      private

      def build_step(name:, args:)
        {
          name: name,
          args: args || {},
          start_time: current_time,
          end_time: nil,
          entries: [],
          children: [],
        }
      end

      def current_time
        Time.now.utc
      end

      def ensure_root!
        raise ArgumentError, "root is not started" unless root
      end

      def emit_step(step, trace_events, pid = 1, tid = 1)
        trace_events << {
          name: step[:name],
          cat: "default",
          ph: "B",
          pid: pid,
          tid: tid,
          args: step[:args],
          ts: timestamp_in_microseconds(step[:start_time]),
        }

        step[:entries].each do |entry|
          trace_events << {
            name: entry[:name],
            cat: "default",
            ph: "B",
            pid: pid,
            tid: tid,
            args: entry[:args],
            ts: timestamp_in_microseconds(entry[:start_time]),
            s: "p",
          }
          trace_events << {
            name: entry[:name],
            cat: "default",
            ph: "E",
            pid: pid,
            tid: tid,
            ts: timestamp_in_microseconds(entry[:end_time]),
            s: "p",
          }
        end

        step[:children].each { |child| emit_step(child, trace_events, pid, tid) }

        trace_events << {
          name: step[:name],
          cat: "default",
          ph: "E",
          pid: pid,
          tid: tid,
          ts: timestamp_in_microseconds(step[:end_time] || current_time),
        }
      end

      def timestamp_in_microseconds(time)
        (time.to_f * 1_000_000).to_i
      end
    end
  end
end
